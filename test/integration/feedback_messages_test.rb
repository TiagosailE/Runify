require "test_helper"

# Todo alerta do Devise e dos controllers (flash[:alert]/[:notice]) precisa
# chegar na tela como toast; antes o layout so exibia flash[:toast] e o login
# com conta inexistente nao mostrava nada.
class FeedbackMessagesTest < ActionDispatch::IntegrationTest
  def assert_toast(message, type)
    toasts = JSON.parse(response.body[/var toasts = (\[.*?\]);/m, 1].to_s)
    assert_includes toasts, { "message" => message, "type" => type }, "toasts na pagina: #{toasts.inspect}"
  end

  test "login com e-mail sem conta avisa que a conta nao foi encontrada" do
    post user_session_path, params: { user: { email: "ninguem@example.com", password: "qualquer123" } }

    assert_response :unprocessable_entity
    assert_toast "Não encontramos uma conta com este e-mail. Confira o endereço ou crie uma conta.", "error"
  end

  test "login com senha errada avisa que a senha esta incorreta" do
    post user_session_path, params: { user: { email: "one@example.com", password: "errada123" } }

    assert_response :unprocessable_entity
    assert_toast "Senha incorreta. Se você criou a conta com o Google, use \"Continuar com Google\".", "error"
  end

  test "login com e-mail vazio, mal formatado ou sem senha mostra o erro no campo" do
    post user_session_path, params: { user: { email: "", password: "x" } }
    assert_response :unprocessable_entity
    assert_select "[data-field-error=email]", text: "E-mail não pode ficar em branco"

    post user_session_path, params: { user: { email: "sem-arroba", password: "x" } }
    assert_response :unprocessable_entity
    assert_select "[data-field-error=email]", text: /E-mail inválido/

    post user_session_path, params: { user: { email: "one@example.com", password: "" } }
    assert_response :unprocessable_entity
    assert_select "[data-field-error=password]", text: "Senha não pode ficar em branco"
    assert_select "input[name='user[email]'][value='one@example.com']"
  end

  test "pagina protegida sem login explica por que voltou para o login" do
    get dashboard_path
    follow_redirect!

    assert_toast "Você precisa fazer login ou se cadastrar antes de continuar.", "error"
  end

  test "login certo mostra boas-vindas" do
    post user_session_path, params: { user: { email: "one@example.com", password: "password1234" } }
    follow_redirect!

    assert_toast "Login realizado com sucesso.", "success"
  end

  test "cadastro com e-mail ja usado, senha curta e campos vazios mostra cada erro no campo" do
    post user_registration_path, params: {
      user: { username: "", email: "one@example.com", password: "123", password_confirmation: "123", terms_accepted: "0" }
    }

    assert_response :unprocessable_entity
    assert_select "[data-field-error=email]", text: /E-mail já está cadastrado/
    assert_select "[data-field-error=password]", text: "Senha é muito curta: use pelo menos 6 caracteres"
    assert_select "[data-field-error=terms_accepted]"
    assert_toast "Não foi possível criar a conta. Confira os campos destacados.", "error"
  end

  test "cadastro com e-mail vazio ou invalido mostra o erro no campo" do
    post user_registration_path, params: {
      user: { email: "", password: "password1234", password_confirmation: "password1234", terms_accepted: "1" }
    }
    assert_select "[data-field-error=email]", text: "E-mail não pode ficar em branco"

    post user_registration_path, params: {
      user: { email: "nome@", password: "password1234", password_confirmation: "password1234", terms_accepted: "1" }
    }
    assert_select "[data-field-error=email]", text: /E-mail inválido/
  end

  test "codigo de Pacer invalido aparece como toast" do
    sign_in users(:one)
    post join_by_code_pacers_path, params: { code: "NAOEXISTE" }
    follow_redirect!

    assert_toast "Código inválido. Confira com quem te convidou.", "error"
  end
end
