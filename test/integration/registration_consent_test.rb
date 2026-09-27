require "test_helper"

# Checkbox de consentimento (LGPD): sem ele o cadastro tem que falhar, e com
# ele o timestamp real de aceite precisa ficar registrado -- e a evidencia
# que provaria consentimento se algum dia fosse preciso.
class RegistrationConsentTest < ActionDispatch::IntegrationTest
  def valid_params(terms_accepted: "1")
    {
      user: {
        username: "Nova Corredora",
        email: "nova-#{SecureRandom.hex(4)}@example.com",
        password: "password1234",
        password_confirmation: "password1234",
        terms_accepted: terms_accepted
      }
    }
  end

  test "cadastro com o checkbox explicitamente desmarcado falha" do
    assert_no_difference "User.count" do
      post user_registration_path, params: valid_params(terms_accepted: "0")
    end

    assert_response :unprocessable_entity
  end

  # Achado ao vivo: AcceptanceValidator tem allow_nil: true por padrao no
  # Rails -- a checagem so roda se o campo NAO for nil. Sem allow_nil: false
  # explicito, um POST que omite terms_accepted inteiramente (nao manda "0"
  # nem "1") passa batido sem consentimento nenhum. f.check_box do form real
  # sempre manda "0" via hidden field quando desmarcado, mas um POST direto
  # (curl, form adulterado) pode simplesmente omitir a chave.
  test "cadastro sem enviar o parametro terms_accepted falha" do
    params = valid_params
    params[:user].delete(:terms_accepted)

    assert_no_difference "User.count" do
      post user_registration_path, params: params
    end

    assert_response :unprocessable_entity
  end

  test "cadastro aceitando os termos grava terms_accepted_at" do
    assert_difference "User.count", 1 do
      post user_registration_path, params: valid_params
    end

    user = User.order(:created_at).last
    assert user.terms_accepted_at.present?
    assert_in_delta Time.current, user.terms_accepted_at, 5.seconds
  end
end
