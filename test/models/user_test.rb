require "test_helper"

# O min/max do formulario nao vale nada (contorna-se pelo DevTools). Dado
# impossivel precisa parar no model, senao alimenta a IA com premissa falsa
# e contamina o dado coletado para o TG.
class UserTest < ActiveSupport::TestCase
  def build_user(**attrs)
    User.new(
      {
        email: "user-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        username: "Teste",
        terms_accepted: true
      }.merge(attrs)
    )
  end

  test "conta nova nasce com as notificacoes ligadas" do
    user = build_user
    user.save!

    assert user.reload.notifications_enabled?
  end

  test "aceita tempos de prova plausíveis" do
    user = build_user(best_5k_time: 25 * 60, best_10k_time: 55 * 60, best_half_marathon_time: 120 * 60)

    assert user.valid?, user.errors.full_messages.inspect
  end

  test "rejeita 5km mais rápido que o recorde mundial" do
    user = build_user(best_5k_time: 3 * 60)

    assert_not user.valid?
    assert user.errors[:best_5k_time].any?
  end

  test "rejeita 10km mais rápido que o recorde mundial" do
    user = build_user(best_10k_time: 5 * 60)

    assert_not user.valid?
    assert user.errors[:best_10k_time].any?
  end

  test "rejeita meia maratona mais rápida que o recorde mundial" do
    user = build_user(best_half_marathon_time: 20 * 60)

    assert_not user.valid?
    assert user.errors[:best_half_marathon_time].any?
  end

  test "rejeita tempo de prova absurdamente longo" do
    user = build_user(best_5k_time: 10.hours.to_i)

    assert_not user.valid?
  end

  test "rejeita volume semanal impossível" do
    user = build_user(weekly_mileage: 900)

    assert_not user.valid?
    assert user.errors[:weekly_mileage].any?
  end

  test "aceita campos de performance em branco" do
    user = build_user

    assert user.valid?, user.errors.full_messages.inspect
  end

  # Piso temporario [E]: Runify restrito a maiores de 18 por enquanto --
  # tratamento de dado de menor exige consentimento parental (LGPD Art. 14),
  # que o app ainda nao implementa.
  test "rejeita menor de 18 anos" do
    user = build_user(birth_date: 16.years.ago.to_date)

    assert_not user.valid?
    assert user.errors[:age].any?
  end

  test "aceita maior de 18 anos" do
    user = build_user(birth_date: 20.years.ago.to_date)

    assert user.valid?, user.errors.full_messages.inspect
  end

  test "rejeita uid duplicado para o mesmo provider" do
    build_user(provider: "google_oauth2", uid: "dup-uid").save!
    duplicate = build_user(provider: "google_oauth2", uid: "dup-uid")

    assert_not duplicate.valid?
    assert duplicate.errors[:uid].any?
  end
end
