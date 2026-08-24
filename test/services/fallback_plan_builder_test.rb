require "test_helper"

class FallbackPlanBuilderTest < ActiveSupport::TestCase
  def build_user(**attrs)
    User.create!(
      {
        email: "fallback-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        username: "Teste",
        terms_accepted: true
      }.merge(attrs)
    )
  end

  # Propriedade central: o fallback existe para ser o plano seguro quando a
  # IA falha. Se ele mesmo nao passasse no validador, nao serviria de rede.
  test "plano de fallback passa no proprio validador para toda persona" do
    personas = {
      "nunca correu" => build_user(running_experience: "beginner", goal: "Correr 5km"),
      "iniciante com volume baixo" => build_user(running_experience: "beginner", weekly_mileage: 8, preferred_training_days: [ 1, 3, 5 ]),
      "intermediario" => build_user(running_experience: "intermediate", weekly_mileage: 30, preferred_training_days: [ 1, 2, 4, 6 ]),
      "avancado" => build_user(running_experience: "advanced", weekly_mileage: 70, preferred_training_days: [ 1, 2, 3, 4, 5, 6 ]),
      "sem dado nenhum" => build_user
    }

    personas.each do |label, user|
      envelope = TrainingEnvelope.new(user)
      plan = FallbackPlanBuilder.new(user, envelope).build
      validator = TrainingPlanValidator.new(plan, envelope)

      assert validator.valid?, "#{label}: #{validator.violations.join(' | ')}"
    end
  end

  test "iniciante absoluto recebe caminhada corrida e nao corrida continua" do
    user = build_user(running_experience: "beginner", goal: "Correr meus primeiros 5km")
    plan = FallbackPlanBuilder.new(user).build

    formats = plan["workouts"].map { |w| w["format"] }.uniq

    assert_equal [ "run_walk" ], formats
    assert(plan["workouts"].all? { |w| w["steps"].present? })
  end

  test "primeiro treino de quem nunca correu comeca com bloco curto de corrida" do
    user = build_user(running_experience: "beginner", goal: "Correr meus primeiros 5km")
    plan = FallbackPlanBuilder.new(user).build

    first = plan["workouts"].min_by { |w| [ w["week"], w["day"] ] }
    run_step = first["steps"].find { |s| s["activity"] == "run" }

    assert_operator run_step["seconds"], :<=, 90
    assert_nil first["distance_km"]
  end

  test "progressao de caminhada corrida aumenta o bloco de corrida ao longo das semanas" do
    user = build_user(running_experience: "beginner")
    plan = FallbackPlanBuilder.new(user).build

    run_seconds_by_week = plan["workouts"].group_by { |w| w["week"] }.transform_values do |workouts|
      workouts.first["steps"].find { |s| s["activity"] == "run" }["seconds"]
    end

    weeks = run_seconds_by_week.keys.sort
    assert_operator run_seconds_by_week[weeks.last], :>, run_seconds_by_week[weeks.first]
  end

  test "plano continuo respeita o teto semanal em toda semana" do
    user = build_user(running_experience: "intermediate", weekly_mileage: 25, preferred_training_days: [ 1, 3, 5 ])
    envelope = TrainingEnvelope.new(user)
    plan = FallbackPlanBuilder.new(user, envelope).build

    plan["workouts"].group_by { |w| w["week"] }.each do |week, workouts|
      total = workouts.sum { |w| w["distance_km"].to_f }
      assert_operator total, :<=, envelope.max_weekly_km_for_week(week)
    end
  end

  test "usa apenas os dias declarados pelo atleta" do
    user = build_user(running_experience: "intermediate", weekly_mileage: 25, preferred_training_days: [ 2, 4 ])
    plan = FallbackPlanBuilder.new(user).build

    assert_equal [ 2, 4 ], plan["workouts"].map { |w| w["day"] }.uniq.sort
  end

  test "numero de semanas bate com o envelope" do
    user = build_user(running_experience: "beginner")
    envelope = TrainingEnvelope.new(user)
    plan = FallbackPlanBuilder.new(user, envelope).build

    assert_equal envelope.plan_weeks, plan["plan_duration_weeks"]
    assert_equal envelope.plan_weeks, plan["workouts"].map { |w| w["week"] }.uniq.size
  end
end
