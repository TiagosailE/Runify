require "test_helper"

# Personas adversariais: o objetivo destes testes nao e cobrir o caminho
# feliz, e garantir que dado absurdo ou ausente nunca produza limite
# perigoso. Se algum destes quebrar, a trava contra alucinacao regrediu.
class TrainingEnvelopeTest < ActiveSupport::TestCase
  def build_user(**attrs)
    User.create!(
      {
        email: "envelope-#{SecureRandom.hex(4)}@example.com",
        password: "password1234",
        username: "Teste",
        terms_accepted: true
      }.merge(attrs)
    )
  end

  test "quem nunca correu e classificado como iniciante absoluto" do
    user = build_user(running_experience: "beginner", goal: "Correr meus primeiros 5km")
    envelope = TrainingEnvelope.new(user)

    assert_equal :absolute_beginner, envelope.level
    assert envelope.run_walk?
  end

  # O bug reportado: objetivo "primeiros 5km" virava treino de 5km no dia 1.
  test "objetivo de 5km nao autoriza treino de 5km na primeira semana" do
    user = build_user(running_experience: "beginner", goal: "Correr meus primeiros 5km")
    envelope = TrainingEnvelope.new(user)

    assert_operator envelope.max_single_run_km, :<, 5.0
    assert_operator envelope.max_single_run_km_for_week(1), :<, 5.0
  end

  test "iniciante absoluto tem plano longo o suficiente para chegar nos 5km" do
    user = build_user(running_experience: "beginner")
    envelope = TrainingEnvelope.new(user)

    assert_operator envelope.plan_weeks, :>=, 8
    assert_operator envelope.max_single_run_km_for_week(envelope.plan_weeks), :>=, 5.0
  end

  test "sem tempo comprovado nao prescreve pace de elite" do
    user = build_user(running_experience: "beginner")
    envelope = TrainingEnvelope.new(user)

    # O teto de permissao pode ser rapido, mas a SUGESTAO nunca pode ser.
    assert_operator envelope.suggested_easy_pace_seconds, :>=, 420
  end

  # 999 e o maior valor que a coluna aceita -- absurdo, mas gravavel se
  # alguem burlar a validacao do model. O envelope corta mesmo assim.
  test "volume semanal declarado absurdo e cortado no limite do model" do
    user = build_user(running_experience: "advanced")
    user.update_column(:weekly_mileage, 999)
    envelope = TrainingEnvelope.new(user)

    assert_operator envelope.max_weekly_km, :<=, User::MAX_WEEKLY_MILEAGE_KM * 1.1
  end

  test "validacao do model rejeita volume semanal impossivel" do
    user = build_user(running_experience: "advanced")
    user.weekly_mileage = 999

    assert_not user.valid?
    assert user.errors[:weekly_mileage].any?
  end

  test "teto de treino unico respeita a corrida mais longa recente" do
    user = build_user(running_experience: "intermediate", weekly_mileage: 30)
    user.activities.create!(
      name: "Longao", sport_type: "Run", distance: 10_000, duration: 3_000,
      moving_time: 3_000, start_date: 3.days.ago, source: "manual"
    )
    envelope = TrainingEnvelope.new(user)

    assert_equal 10.0, envelope.longest_recent_run_km
    assert_equal 11.0, envelope.max_single_run_km
  end

  test "pedal recente nao conta como base do teto de corrida" do
    user = build_user(running_experience: "intermediate", weekly_mileage: 30)
    user.activities.create!(
      name: "Pedal", sport_type: "Ride", distance: 50_000, duration: 5_400,
      moving_time: 5_400, start_date: 3.days.ago, source: "manual"
    )
    envelope = TrainingEnvelope.new(user)

    assert_equal 0.0, envelope.longest_recent_run_km
  end

  test "corrida antiga nao conta como base recente" do
    user = build_user(running_experience: "intermediate", weekly_mileage: 20)
    user.activities.create!(
      name: "Antiga", sport_type: "Run", distance: 30_000, duration: 9_000,
      moving_time: 9_000, start_date: 90.days.ago, source: "manual"
    )
    envelope = TrainingEnvelope.new(user)

    assert_equal 0.0, envelope.longest_recent_run_km
    assert_operator envelope.max_single_run_km, :<, 30.0
  end

  test "teto cresce por semana mas nunca explode" do
    user = build_user(running_experience: "intermediate", weekly_mileage: 30)
    envelope = TrainingEnvelope.new(user)

    week1 = envelope.max_single_run_km_for_week(1)
    week6 = envelope.max_single_run_km_for_week(6)

    assert_operator week6, :>, week1
    assert_operator week6, :<, week1 * 2
  end

  test "semana fora do plano nao burla o teto" do
    user = build_user(running_experience: "intermediate", weekly_mileage: 30)
    envelope = TrainingEnvelope.new(user)

    ceiling = envelope.max_single_run_km_for_week(TrainingEnvelope::MAX_PLAN_WEEKS)

    assert_equal ceiling, envelope.max_single_run_km_for_week(999)
    assert_equal envelope.max_single_run_km, envelope.max_single_run_km_for_week(0)
  end

  test "pace permitido nunca fica mais rapido que o limite humano" do
    user = build_user(running_experience: "advanced", best_5k_time: User::MIN_5K_TIME_SECONDS)
    envelope = TrainingEnvelope.new(user)

    assert_operator envelope.fastest_pace_seconds, :>=, TrainingEnvelope::FASTEST_HUMAN_PACE
  end

  test "dias de treino caem num padrao seguro quando nao ha nenhum informado" do
    user = build_user(running_experience: "beginner")
    envelope = TrainingEnvelope.new(user)

    assert_equal 3, envelope.training_days.size
    assert(envelope.training_days.all? { |day| day.between?(1, 7) })
  end

  test "dias invalidos vindos do banco sao descartados" do
    user = build_user(running_experience: "beginner")
    user.update_column(:preferred_training_days, [ 0, 9, 3 ])
    envelope = TrainingEnvelope.new(user)

    assert_equal [ 3 ], envelope.training_days
  end

  test "sessoes por semana nunca passa dos dias disponiveis" do
    user = build_user(running_experience: "advanced", weekly_mileage: 60, preferred_training_days: [ 2, 5 ])
    envelope = TrainingEnvelope.new(user)

    assert_equal 2, envelope.sessions_per_week
  end

  test "o prompt avisa que a semana 1 e a atual e que dia passado e descartado" do
    user = build_user(running_experience: "advanced", weekly_mileage: 60)
    section = TrainingEnvelope.new(user).to_prompt_section

    assert_includes section, "A semana 1 e a semana atual"
    assert_not_includes section, "O plano comeca hoje"
  end

  # Teto de duracao do ajuste da IA: o mesmo teto de distancia da semana no
  # pace mais lento permitido, limitado ao que o validador chama de implausivel.
  test "teto de duracao do iniciante absoluto vem do teto de distancia da semana" do
    envelope = TrainingEnvelope.new(build_user(running_experience: "beginner"))

    assert_equal 2160, envelope.max_duration_seconds_for_week(1) # 3.0km x 12:00/km
    assert_operator envelope.max_duration_seconds_for_week(5), :>, envelope.max_duration_seconds_for_week(1)
  end

  test "teto de duracao nunca passa do limite de plausibilidade do validador" do
    envelope = TrainingEnvelope.new(build_user(running_experience: "advanced", weekly_mileage: 60))

    assert_equal 24.0 * TrainingEnvelope::SLOWEST_HUMAN_PACE, envelope.max_duration_seconds_for_week(1)
    assert_equal TrainingEnvelope::MAX_SESSION_MINUTES * 60, envelope.max_duration_seconds_for_week(12)
  end
end
