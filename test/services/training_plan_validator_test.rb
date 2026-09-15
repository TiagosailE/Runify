require "test_helper"

# Cada teste aqui e um jeito conhecido da IA alucinar. Se algum passar a
# retornar "valido", um plano perigoso volta a chegar no usuario.
class TrainingPlanValidatorTest < ActiveSupport::TestCase
  def build_user(**attrs)
    User.create!(
      {
        email: "validator-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        username: "Teste",
        terms_accepted: true
      }.merge(attrs)
    )
  end

  def runner
    @runner ||= begin
      user = build_user(running_experience: "intermediate", weekly_mileage: 30, preferred_training_days: [ 1, 3, 5 ])
      user.activities.create!(
        name: "Base", sport_type: "Run", distance: 10_000, duration: 3_000,
        moving_time: 3_000, start_date: 2.days.ago, source: "manual"
      )
      user
    end
  end

  def envelope_for(user)
    TrainingEnvelope.new(user)
  end

  def workout(**overrides)
    {
      "week" => 1, "day" => 1, "type" => "Corrida Leve", "format" => "continuous",
      "distance_km" => 5.0, "duration_minutes" => 30, "pace" => "6:00",
      "description" => "leve", "instructions" => "leve"
    }.merge(overrides)
  end

  def plan(workouts)
    { "analysis" => "ok", "plan_duration_weeks" => 6, "workouts" => workouts }
  end

  test "plano dentro do envelope e aprovado" do
    validator = TrainingPlanValidator.new(plan([ workout ]), envelope_for(runner))

    assert validator.valid?, validator.violations.inspect
  end

  test "rejeita distancia acima do teto da semana" do
    validator = TrainingPlanValidator.new(plan([ workout("distance_km" => 42.0) ]), envelope_for(runner))

    assert_not validator.valid?
    assert_match(/passa do limite/, validator.violations.join)
  end

  test "rejeita pace humanamente impossivel" do
    validator = TrainingPlanValidator.new(plan([ workout("pace" => "1:00") ]), envelope_for(runner))

    assert_not validator.valid?
    assert_match(/mais rápido que o limite/, validator.violations.join)
  end

  test "rejeita pace impossivel dentro de uma faixa" do
    validator = TrainingPlanValidator.new(plan([ workout("pace" => "0:45-1:10") ]), envelope_for(runner))

    assert_not validator.valid?
  end

  # Persona real: fez um longao isolado, mas o volume semanal e baixo. Cada
  # treino cabe no teto individual e ainda assim a semana inteira estoura.
  test "rejeita volume semanal acima do teto mesmo com treinos individuais validos" do
    user = build_user(running_experience: "intermediate", weekly_mileage: 12, preferred_training_days: [ 1, 3, 5 ])
    user.activities.create!(
      name: "Longao isolado", sport_type: "Run", distance: 10_000, duration: 3_000,
      moving_time: 3_000, start_date: 2.days.ago, source: "manual"
    )
    envelope = envelope_for(user)
    ceiling = envelope.max_single_run_km_for_week(1)

    many = [ 1, 3, 5 ].map { |day| workout("day" => day, "distance_km" => ceiling) }
    validator = TrainingPlanValidator.new(plan(many), envelope)

    assert_operator ceiling * 3, :>, envelope.max_weekly_km_for_week(1)
    assert_not validator.valid?
    assert_match(/volume/, validator.violations.join)
  end

  test "rejeita dia fora dos dias disponiveis do atleta" do
    validator = TrainingPlanValidator.new(plan([ workout("day" => 2) ]), envelope_for(runner))

    assert_not validator.valid?
    assert_match(/dias disponíveis/, validator.violations.join)
  end

  test "rejeita semana fora do plano" do
    validator = TrainingPlanValidator.new(plan([ workout("week" => 99) ]), envelope_for(runner))

    assert_not validator.valid?
    assert_match(/fora do intervalo esperado/, validator.violations.join)
  end

  test "week_range customizado rejeita semana dentro do plano mas fora do range" do
    validator = TrainingPlanValidator.new(plan([ workout("week" => 1) ]), envelope_for(runner), week_range: 3..6)

    assert_not validator.valid?
    assert_match(/fora do intervalo esperado \(3 a 6\)/, validator.violations.join)
  end

  test "week_range customizado aceita semana dentro do range informado" do
    validator = TrainingPlanValidator.new(plan([ workout("week" => 3) ]), envelope_for(runner), week_range: 3..6)

    assert validator.valid?, validator.violations.inspect
  end

  test "rejeita corrida continua para quem nunca correu" do
    beginner = build_user(running_experience: "beginner")
    validator = TrainingPlanValidator.new(plan([ workout("distance_km" => 1.0) ]), envelope_for(beginner))

    assert_not validator.valid?
    assert_match(/run_walk/, validator.violations.join)
  end

  test "aceita run_walk sem distancia" do
    beginner = build_user(running_experience: "beginner", preferred_training_days: [ 1, 3, 5 ])
    run_walk = workout("format" => "run_walk", "distance_km" => nil, "pace" => "confortável")
    validator = TrainingPlanValidator.new(plan([ run_walk ]), envelope_for(beginner))

    assert validator.valid?, validator.violations.inspect
  end

  test "rejeita corrida continua sem distancia" do
    validator = TrainingPlanValidator.new(plan([ workout("distance_km" => nil) ]), envelope_for(runner))

    assert_not validator.valid?
    assert_match(/distância ausente/, validator.violations.join)
  end

  test "rejeita duracao implausivel" do
    validator = TrainingPlanValidator.new(plan([ workout("duration_minutes" => 600) ]), envelope_for(runner))

    assert_not validator.valid?
    assert_match(/implausível/, validator.violations.join)
  end

  test "rejeita formato desconhecido" do
    validator = TrainingPlanValidator.new(plan([ workout("format" => "teleporte") ]), envelope_for(runner))

    assert_not validator.valid?
    assert_match(/formato/, validator.violations.join)
  end

  test "rejeita plano sem treinos" do
    validator = TrainingPlanValidator.new(plan([]), envelope_for(runner))

    assert_not validator.valid?
  end

  test "rejeita resposta sem a chave workouts" do
    validator = TrainingPlanValidator.new({ "analysis" => "ok" }, envelope_for(runner))

    assert_not validator.valid?
  end
end
