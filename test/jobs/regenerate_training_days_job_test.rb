require "test_helper"

class RegenerateTrainingDaysJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  def stub_gemini(response)
    fake = ->(_prompt, **_opts) { response }
    GeminiClient.stub :generate_json, fake do
      yield
    end
  end

  test "regenera so as semanas pendentes do plano ativo a partir da semana atual" do
    travel_to Date.new(2026, 9, 14) do # segunda: o dia 2 da semana atual ainda nao passou
      user = users(:one)
      # O job roda depois que o controller ja salvou a preferencia nova --
      # aqui simula o estado em que ele encontra o usuario ao ser executado.
      user.update!(running_experience: "intermediate", weekly_mileage: 30, preferred_training_days: [ 2, 4 ])
      plan = user.training_plans.create!(
        goal: "Teste", status: "active", start_date: 2.weeks.ago.to_date,
        end_date: Date.current + 4.weeks, total_weeks: 6, plan_data: {}
      )
      monday = plan.start_date.beginning_of_week(:monday)
      old_pending = plan.workouts.create!(
        week_number: plan.current_week, day_of_week: 1, scheduled_date: monday + (plan.current_week - 1).weeks,
        workout_type: "Corrida Leve", workout_format: "continuous", distance: 5.0, duration: 1800,
        pace: "6:00", description: "leve", instructions: "leve", status: "pending"
      )

      new_plan_data = {
        "analysis" => "continuacao", "plan_duration_weeks" => 6,
        "workouts" => [ {
          "week" => plan.current_week, "day" => 2, "type" => "Corrida Leve", "format" => "continuous",
          "distance_km" => 5.0, "duration_minutes" => 30, "pace" => "6:00",
          "description" => "leve", "instructions" => "leve"
        } ]
      }

      stub_gemini(new_plan_data) { RegenerateTrainingDaysJob.new.perform(user.id) }

      assert_not Workout.exists?(old_pending.id)
      assert_equal 1, plan.workouts.where(week_number: plan.current_week, day_of_week: 2).count
    end
  end

  test "nao faz nada quando o usuario nao tem plano ativo" do
    user = users(:one)
    assert_nil user.active_training_plan

    assert_nothing_raised { RegenerateTrainingDaysJob.new.perform(user.id) }
  end

  test "nao faz nada quando o plano ja passou de todas as semanas" do
    user = users(:one)
    plan = user.training_plans.create!(
      goal: "Teste", status: "active", start_date: 10.weeks.ago.to_date,
      end_date: 4.weeks.ago, total_weeks: 4, plan_data: {}
    )

    assert_operator plan.current_week, :>, plan.total_weeks

    assert_nothing_raised { RegenerateTrainingDaysJob.new.perform(user.id) }
    assert_equal 0, plan.workouts.count
  end

  # GeminiClient::Error cai no fallback deterministico do proprio
  # AiTrainingService (nao chega a estourar aqui) -- o rescue do job existe
  # para o que sobra disso: falha de rede crua (ex: timeout), que hoje
  # escapa do mecanismo de retry/fallback. Ver task registrada sobre
  # GeminiClient nao envolver Net::ReadTimeout como GeminiClient::Error.
  test "loga o erro em vez de propagar quando a falha nao e recuperavel pelo fallback" do
    user = users(:one)
    user.update!(preferred_training_days: [ 1, 3, 5 ])
    user.training_plans.create!(
      goal: "Teste", status: "active", start_date: Date.current,
      end_date: Date.current + 4.weeks, total_weeks: 4, plan_data: {}
    )

    GeminiClient.stub :generate_json, ->(*) { raise Net::ReadTimeout, "falhou" } do
      assert_nothing_raised { RegenerateTrainingDaysJob.new.perform(user.id) }
    end
  end

  test "usuario inexistente nao levanta excecao" do
    assert_nothing_raised { RegenerateTrainingDaysJob.new.perform(-1) }
  end
end
