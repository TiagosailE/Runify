require "test_helper"

class AiAdjustmentServiceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  def setup
    @user = User.create!(
      email: "adjust-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      username: "Teste",
      running_experience: "intermediate",
      weekly_mileage: 30,
      preferred_training_days: [ 1, 3, 5 ],
      terms_accepted: true
    )

    @plan = @user.training_plans.create!(
      goal: "Melhorar 10km",
      status: "active",
      start_date: 1.week.ago.to_date,
      end_date: 5.weeks.from_now.to_date,
      total_weeks: 6,
      plan_data: {}
    )

    # Semana 1 concluida, semana 2 pendente -- e a semana 2 em diante que o
    # ajuste mexe.
    @plan.workouts.create!(
      week_number: 1, day_of_week: 1, scheduled_date: 1.week.ago.to_date,
      workout_type: "Corrida Leve", workout_format: "continuous",
      distance: 5.0, duration: 1800, pace: "6:00", status: "completed",
      workout_details: { "user_feedback" => { "difficulty" => 3, "notes" => "ok" } }
    )

    @future = @plan.workouts.create!(
      week_number: 2, day_of_week: 1, scheduled_date: Date.today,
      workout_type: "Corrida Leve", workout_format: "continuous",
      distance: 5.0, duration: 1800, pace: "6:00", status: "pending"
    )
  end

  def stub_gemini(response)
    GeminiClient.stub :generate_json, ->(_prompt, **_opts) { response } do
      yield
    end
  end

  def adjustment(type, percentage, red_flags: [])
    {
      "analysis" => "análise",
      "adjustment_type" => type,
      "adjustment_percentage" => percentage,
      "reasoning" => "motivo",
      "recommendations" => [],
      "red_flags" => red_flags
    }
  end

  # O bug: "maintain" multiplicava por 1.05, ou seja, aumentava 5% toda
  # semana em que a IA pedia justamente para NAO aumentar.
  test "maintain nao altera a carga" do
    stub_gemini(adjustment("maintain", 0)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_in_delta 5.0, @future.reload.distance.to_f, 0.001
    assert_equal 1800, @future.duration
  end

  test "increase aumenta a carga" do
    stub_gemini(adjustment("increase", 10)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_in_delta 5.5, @future.reload.distance.to_f, 0.001
  end

  test "decrease reduz a carga" do
    stub_gemini(adjustment("decrease", 10)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_in_delta 4.5, @future.reload.distance.to_f, 0.001
  end

  # Sem teto, aumentos sucessivos compunham sem limite semana apos semana.
  test "aumento nunca passa do teto do envelope para aquela semana" do
    @future.update_columns(distance: 40.0)

    stub_gemini(adjustment("increase", 20)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    ceiling = TrainingEnvelope.new(@user).max_single_run_km_for_week(2)

    assert_operator @future.reload.distance.to_f, :<=, ceiling
  end

  # Aumento e mais arriscado que reducao: limites diferentes por direcao.
  test "aumento pedido acima de 10 por cento e cortado em 10" do
    stub_gemini(adjustment("increase", 20)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_in_delta 5.5, @future.reload.distance.to_f, 0.001
    assert_equal 1980, @future.duration
  end

  test "percentual absurdo de aumento tambem e cortado em 10" do
    stub_gemini(adjustment("increase", 500)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_in_delta 5.5, @future.reload.distance.to_f, 0.001
  end

  test "reducao pedida acima de 20 por cento e cortada em 20" do
    stub_gemini(adjustment("decrease", 30)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_in_delta 4.0, @future.reload.distance.to_f, 0.001
    assert_equal 1440, @future.duration
  end

  test "reducao dentro do limite e aplicada como veio" do
    stub_gemini(adjustment("decrease", 15)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_in_delta 4.25, @future.reload.distance.to_f, 0.001
  end

  # O bug: cada feedback (e o job de segunda) chamava o ajuste de novo, e cada
  # chamada multiplicava todos os pendentes restantes.
  test "duas chamadas na mesma semana ajustam so uma vez" do
    calls = 0
    counting = ->(_prompt, **_opts) do
      calls += 1
      adjustment("increase", 10)
    end

    GeminiClient.stub :generate_json, counting do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
      AiAdjustmentService.new(@user, TrainingPlan.find(@plan.id)).analyze_and_adjust
    end

    assert_equal 1, calls
    assert_in_delta 5.5, @future.reload.distance.to_f, 0.001
    assert_equal 2, @plan.reload.last_adjusted_week
  end

  test "na semana seguinte o plano pode ser ajustado de novo" do
    stub_gemini(adjustment("increase", 10)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust

      later = @plan.workouts.create!(
        week_number: 3, day_of_week: 1, scheduled_date: Date.current + 1.week,
        workout_type: "Corrida Leve", workout_format: "continuous",
        distance: 5.0, duration: 1800, pace: "6:00", status: "pending"
      )
      @plan.workouts.where(week_number: 2).update_all(status: "completed")

      travel_to Date.current + 1.week do
        assert_equal 3, @plan.reload.current_week
        AiAdjustmentService.new(@user, @plan).analyze_and_adjust
      end

      assert_equal 3, @plan.reload.last_adjusted_week
      assert_in_delta 5.5, later.reload.distance.to_f, 0.001
    end
  end

  test "falha da IA nao marca a semana como ajustada" do
    GeminiClient.stub :generate_json, ->(*) { raise GeminiClient::Error, "503" } do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_nil @plan.reload.last_adjusted_week
    assert_in_delta 5.0, @future.reload.distance.to_f, 0.001
  end

  test "sem treino concluido na semana anterior nada e ajustado nem marcado" do
    @plan.workouts.where(week_number: 1).update_all(status: "pending")

    GeminiClient.stub :generate_json, ->(*) { flunk "nao deveria chamar a IA" } do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_nil @plan.reload.last_adjusted_week
  end

  # Sem teto de duracao, o plano run/walk de iniciante (sem distancia) crescia
  # 10% por semana sem limite nenhum.
  test "run walk apos varias semanas de aumento nunca passa do teto de duracao" do
    beginner = User.create!(
      email: "runwalk-#{SecureRandom.hex(4)}@example.com", password: "password123",
      username: "Iniciante", running_experience: "beginner", terms_accepted: true
    )
    envelope = TrainingEnvelope.new(beginner)
    assert envelope.run_walk?

    monday = Date.new(2026, 9, 7)
    plan = beginner.training_plans.create!(
      goal: "Correr 5km", status: "active", start_date: monday,
      end_date: monday + 9.weeks - 1.day, total_weeks: 9, plan_data: {}
    )
    (1..9).each do |week|
      plan.workouts.create!(
        week_number: week, day_of_week: 1, scheduled_date: monday + (week - 1).weeks,
        workout_type: "Caminhada/Corrida", workout_format: "run_walk",
        distance: nil, duration: 2400, pace: "confortável", status: "pending"
      )
    end

    (2..8).each do |week|
      travel_to monday + (week - 1).weeks do
        plan.workouts.where(week_number: week - 1).update_all(status: "completed")
        stub_gemini(adjustment("increase", 10)) do
          AiAdjustmentService.new(beginner, TrainingPlan.find(plan.id)).analyze_and_adjust
        end
      end
    end

    plan.workouts.where(status: "pending").each do |workout|
      ceiling = envelope.max_duration_seconds_for_week(workout.week_number)
      assert_operator workout.duration, :<=, [ ceiling, 2400 ].max,
                      "semana #{workout.week_number}: #{workout.duration}s passa de #{ceiling}s"
    end

    grown = plan.workouts.find_by(week_number: 3)
    assert_operator grown.duration, :>, 2400, "o aumento dentro do teto deveria ter sido aplicado"
    assert_equal envelope.max_duration_seconds_for_week(3), grown.duration
  end

  test "aumento nunca reduz um treino que ja estava acima do teto de duracao" do
    ceiling = TrainingEnvelope.new(@user).max_duration_seconds_for_week(2)
    @future.update_columns(duration: ceiling + 600)

    stub_gemini(adjustment("increase", 10)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_equal ceiling + 600, @future.reload.duration
  end

  test "red flags notificam mesmo com as notificacoes desligadas" do
    @user.update!(notifications_enabled: false)

    assert_difference -> { @user.notifications.count }, 1 do
      stub_gemini(adjustment("decrease", 10, red_flags: [ "risco de lesão" ])) do
        AiAdjustmentService.new(@user, @plan).analyze_and_adjust
      end
    end

    assert_match(/risco de lesão/, @user.notifications.last.message)
  end

  test "treino de caminhada corrida sem distancia nao quebra o ajuste" do
    @future.update!(workout_format: "run_walk", distance: nil)

    stub_gemini(adjustment("increase", 10)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    assert_nil @future.reload.distance
    assert_operator @future.duration, :>, 1800
  end
end
