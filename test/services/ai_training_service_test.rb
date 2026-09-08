require "test_helper"

# A chamada real da Gemini fica fora do CI (custa dinheiro e e
# nao-deterministica). Aqui o cliente e stubbado para exercitar a
# orquestracao: aprovar, tentar de novo, ou cair no plano deterministico.
class AiTrainingServiceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  def build_user(**attrs)
    User.create!(
      {
        email: "aiplan-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        username: "Teste",
        terms_accepted: true
      }.merge(attrs)
    )
  end

  def runner
    @runner ||= build_user(
      running_experience: "intermediate",
      weekly_mileage: 30,
      preferred_training_days: [ 1, 3, 5 ],
      goal: "Melhorar meu tempo nos 10km"
    )
  end

  def valid_plan_for(user)
    FallbackPlanBuilder.new(user).build
  end

  def insane_plan
    {
      "analysis" => "plano perigoso",
      "plan_duration_weeks" => 6,
      "workouts" => [ {
        "week" => 1, "day" => 1, "type" => "Corrida Leve", "format" => "continuous",
        "distance_km" => 42.0, "duration_minutes" => 60, "pace" => "1:00",
        "description" => "correr 42km", "instructions" => "correr 42km"
      } ]
    }
  end

  def stub_gemini(*responses)
    queue = responses.dup
    fake = ->(_prompt, **_opts) do
      nxt = queue.shift
      raise nxt if nxt.is_a?(StandardError)
      nxt
    end

    GeminiClient.stub :generate_json, fake do
      yield
    end
  end

  test "plano valido da IA e persistido e marcado como origem ai" do
    plan = valid_plan_for(runner)

    training_plan = stub_gemini(plan) { AiTrainingService.new(runner).generate_training_plan }

    assert training_plan.persisted?
    assert_equal "ai", training_plan.plan_data["source"]
    assert_equal plan["workouts"].size, training_plan.workouts.count
  end

  test "plano absurdo dispara retry e o segundo plano valido e usado" do
    training_plan = stub_gemini(insane_plan, valid_plan_for(runner)) do
      AiTrainingService.new(runner).generate_training_plan
    end

    assert_equal "ai_retry", training_plan.plan_data["source"]
    assert(training_plan.workouts.none? { |w| w.distance.to_f > 40 })
  end

  # A garantia principal: mesmo a IA insistindo no absurdo, nada perigoso
  # chega no usuario.
  test "plano absurdo duas vezes cai no fallback deterministico" do
    training_plan = stub_gemini(insane_plan, insane_plan) do
      AiTrainingService.new(runner).generate_training_plan
    end

    envelope = TrainingEnvelope.new(runner)

    assert_equal "fallback", training_plan.plan_data["source"]
    training_plan.workouts.each do |workout|
      assert_operator workout.distance.to_f, :<=, envelope.max_single_run_km_for_week(workout.week_number)
    end
  end

  test "erro na API cai no fallback em vez de estourar para o usuario" do
    training_plan = stub_gemini(
      GeminiClient::Error.new("503 indisponível"),
      GeminiClient::Error.new("503 indisponível")
    ) { AiTrainingService.new(runner).generate_training_plan }

    assert_equal "fallback", training_plan.plan_data["source"]
    assert_operator training_plan.workouts.count, :>, 0
  end

  test "iniciante absoluto recebe treinos run_walk persistidos sem distancia" do
    beginner = build_user(running_experience: "beginner", goal: "Correr meus primeiros 5km")

    training_plan = stub_gemini(GeminiClient::Error.new("falhou"), GeminiClient::Error.new("falhou")) do
      AiTrainingService.new(beginner).generate_training_plan
    end

    assert(training_plan.workouts.all?(&:run_walk?))
    assert(training_plan.workouts.all? { |w| w.distance.nil? })
    assert(training_plan.workouts.all? { |w| w.steps.any? })
  end

  # Bug real reportado: dia 2 (terca) sendo agendado numa quarta porque a data
  # era calculada como offset a partir do dia da geracao, nao como a terca
  # real da semana. 2026-09-08 e uma terca-feira confirmada.
  test "scheduled_date usa o dia da semana real, nao offset a partir de hoje" do
    travel_to Date.new(2026, 9, 8) do # terca-feira
      athlete = build_user(
        running_experience: "intermediate", weekly_mileage: 30,
        preferred_training_days: [ 1, 2 ], goal: "Melhorar meu tempo nos 10km"
      )
      plan = {
        "analysis" => "ok",
        "plan_duration_weeks" => 4,
        "workouts" => [
          { "week" => 1, "day" => 1, "type" => "Corrida Leve", "format" => "continuous",
            "distance_km" => 5.0, "duration_minutes" => 30, "pace" => "6:00",
            "description" => "leve", "instructions" => "leve" },
          { "week" => 1, "day" => 2, "type" => "Corrida Leve", "format" => "continuous",
            "distance_km" => 5.0, "duration_minutes" => 30, "pace" => "6:00",
            "description" => "leve", "instructions" => "leve" }
        ]
      }

      training_plan = stub_gemini(plan) { AiTrainingService.new(athlete).generate_training_plan }

      monday_workout = training_plan.workouts.find_by(day_of_week: 1)
      tuesday_workout = training_plan.workouts.find_by(day_of_week: 2)

      assert_equal Date.new(2026, 9, 7), monday_workout.scheduled_date
      assert_equal Date.new(2026, 9, 8), tuesday_workout.scheduled_date
      assert_equal Date.current, tuesday_workout.scheduled_date
    end
  end

  test "o envelope usado fica registrado junto do plano" do
    training_plan = stub_gemini(valid_plan_for(runner)) do
      AiTrainingService.new(runner).generate_training_plan
    end

    snapshot = training_plan.plan_data["envelope"]

    assert_equal "intermediate", snapshot["level"]
    assert_operator snapshot["max_single_run_km"], :>, 0
  end
end
