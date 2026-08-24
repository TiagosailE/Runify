require "test_helper"

class AiAdjustmentServiceTest < ActiveSupport::TestCase
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

  test "percentual absurdo da IA e cortado no maximo permitido" do
    stub_gemini(adjustment("increase", 500)) do
      AiAdjustmentService.new(@user, @plan).analyze_and_adjust
    end

    limit = 5.0 * (1 + (AiAdjustmentService::MAX_ADJUSTMENT_PERCENT / 100.0))

    assert_operator @future.reload.distance.to_f, :<=, limit
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
