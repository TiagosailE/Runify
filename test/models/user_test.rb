require "test_helper"

# O min/max do formulario nao vale nada (contorna-se pelo DevTools). Dado
# impossivel precisa parar no model, senao alimenta a IA com premissa falsa
# e contamina o dado coletado para o TG.
class UserTest < ActiveSupport::TestCase
  def build_user(**attrs)
    User.new(
      {
        email: "user-#{SecureRandom.hex(4)}@example.com",
        password: "password1234",
        username: "Teste",
        terms_accepted: true
      }.merge(attrs)
    )
  end

  test "rejeita senha com 5 caracteres e aceita com 6" do
    curta = build_user(password: "a" * 5, password_confirmation: "a" * 5)
    assert_not curta.valid?
    assert_includes curta.errors[:password], "é muito curto (mínimo: 6 caracteres)"

    valida = build_user(password: "a" * 6, password_confirmation: "a" * 6)
    assert valida.valid?, valida.errors.full_messages.inspect
  end

  test "avatar aceita PNG ate 5 MB e rejeita tipo fora da lista" do
    valido = build_user
    valido.avatar.attach(io: StringIO.new("conteudo"), filename: "avatar.png", content_type: "image/png")
    assert valido.valid?, valido.errors.full_messages.inspect

    invalido = build_user
    invalido.avatar.attach(io: StringIO.new("<svg></svg>"), filename: "avatar.svg", content_type: "image/svg+xml")
    assert_not invalido.valid?
    assert invalido.errors[:avatar].present?
  end

  test "avatar rejeita arquivo maior que 5 MB mesmo com tipo permitido" do
    user = build_user
    user.avatar.attach(io: StringIO.new("a" * 6.megabytes), filename: "grande.png", content_type: "image/png")

    assert_not user.valid?
    assert user.errors[:avatar].present?
  end

  test "avatar_url sem foto gera SVG local, sem contatar terceiro nem vazar o email" do
    user = build_user(username: "Ana Paula", email: "ana@example.com")
    user.save!

    url = user.avatar_url

    assert_match(/\Adata:image\/svg\+xml;base64,/, url)
    assert_no_match(/ui-avatars/, url)

    decoded = Base64.decode64(url.sub("data:image/svg+xml;base64,", ""))
    assert_no_match("ana@example.com", decoded)
    assert_includes decoded, "AN"
  end

  test "avatar_url sanitiza username malicioso antes de gerar o SVG" do
    user = build_user(username: "<script>alert(1)</script>")
    user.save!

    decoded = Base64.decode64(user.avatar_url.sub("data:image/svg+xml;base64,", ""))

    assert_no_match(/<script>/, decoded)
    assert_includes decoded, "SC"
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
