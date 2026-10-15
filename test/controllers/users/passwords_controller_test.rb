require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  GENERIC_MESSAGE = "Se o e-mail estiver cadastrado, você receberá um código de 6 dígitos em alguns minutos.".freeze
  INVALID_CODE = "Código inválido ou expirado. Confira o e-mail ou peça um código novo".freeze

  def reset_with(code, email: "one@example.com", password: "novasenha123", confirmation: password)
    put user_password_path, params: {
      user: { email: email, reset_code: code, password: password, password_confirmation: confirmation }
    }
  end

  test "tela de login tem o link de esqueci minha senha" do
    get new_user_session_path

    assert_select "a[href='#{new_user_password_path}']", text: "Esqueci minha senha"
  end

  test "tela de pedir recuperacao esta em portugues" do
    get new_user_password_path

    assert_response :success
    assert_includes response.body, "Esqueceu sua senha?"
    assert_select "input[type=submit][value='Enviar código']"
  end

  test "conta com senha recebe um codigo de 6 digitos e segue para a tela do codigo" do
    assert_emails 1 do
      post user_password_path, params: { user: { email: "ONE@example.com " } }
    end

    assert_redirected_to edit_user_password_path
    assert_equal GENERIC_MESSAGE, flash[:toast][:message]

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "one@example.com" ], mail.to
    code = mail.body.decoded[/>(\d{6})</, 1]
    assert code, "codigo nao encontrado no e-mail"
    assert_not_includes mail.body.decoded, "reset_password_token"

    follow_redirect!
    assert_select "input[name='user[email]'][value='one@example.com']"
    assert_select "input[name='user[reset_code]'][autocomplete='one-time-code']"

    reset_with(code)
    assert users(:one).reload.valid_password?("novasenha123")
  end

  test "o banco guarda so o digest do codigo" do
    code = users(:one).send_password_reset_code

    assert_no_match code, users(:one).reload.reset_password_code_digest
  end

  test "conta do Google recebe orientacao para entrar pelo Google, sem codigo" do
    users(:two).update!(provider: "google_oauth2", uid: "123")

    assert_emails 1 do
      post user_password_path, params: { user: { email: "two@example.com" } }
    end

    assert_redirected_to edit_user_password_path
    assert_equal GENERIC_MESSAGE, flash[:toast][:message]
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "two@example.com" ], mail.to
    assert_includes mail.body.encoded, "Continuar com Google"
    assert_includes mail.body.encoded, "accounts.google.com/signin/recovery"
    assert_nil users(:two).reload.reset_password_code_digest
  end

  test "e-mail nao cadastrado recebe a mesma resposta e nenhum e-mail sai" do
    assert_no_emails do
      post user_password_path, params: { user: { email: "ninguem@example.com" } }
    end

    assert_redirected_to edit_user_password_path
    assert_equal GENERIC_MESSAGE, flash[:toast][:message]
  end

  test "e-mail vazio ou mal formatado mostra o erro no campo" do
    post user_password_path, params: { user: { email: "" } }
    assert_response :unprocessable_entity
    assert_includes response.body, "E-mail não pode ficar em branco"

    post user_password_path, params: { user: { email: "sem-arroba" } }
    assert_response :unprocessable_entity
    assert_includes response.body, "E-mail inválido. Confira se digitou certo"
  end

  test "falha na entrega do e-mail nao vira erro na tela nem revela a conta" do
    failing = ->(*) { raise "remetente recusado pelo provedor" }

    UserMailer.stub(:password_reset_code, failing) do
      post user_password_path, params: { user: { email: "one@example.com" } }
    end

    assert_redirected_to edit_user_password_path
    assert_equal GENERIC_MESSAGE, flash[:toast][:message]
  end

  test "tela do codigo abre sem pedido anterior, com o e-mail em branco" do
    get edit_user_password_path

    assert_response :success
    assert_select "input[name='user[email]']:not([value])"
  end

  test "codigo certo define a nova senha e entra na conta" do
    users(:one).update!(weight: 70, goal: "Correr 5km")
    code = users(:one).send_password_reset_code

    reset_with(" #{code[0, 3]} #{code[3, 3]} ")

    assert_redirected_to dashboard_path
    assert users(:one).reload.valid_password?("novasenha123")
    assert_nil users(:one).reset_password_code_digest
  end

  test "codigo usado uma vez nao funciona de novo" do
    code = users(:one).send_password_reset_code
    reset_with(code)
    sign_out :user

    reset_with(code, password: "outrasenha123")

    assert_response :unprocessable_entity
    assert_select "[data-field-error=reset_code]", text: INVALID_CODE
    assert users(:one).reload.valid_password?("novasenha123")
  end

  test "codigo expira em 15 minutos" do
    code = users(:one).send_password_reset_code

    travel 16.minutes do
      reset_with(code)
    end

    assert_response :unprocessable_entity
    assert_select "[data-field-error=reset_code]", text: INVALID_CODE
    assert_not users(:one).reload.valid_password?("novasenha123")
  end

  test "codigo de outra conta nao serve" do
    code = users(:two).send_password_reset_code

    reset_with(code, email: "one@example.com")

    assert_response :unprocessable_entity
    assert_not users(:one).reload.valid_password?("novasenha123")
  end

  test "cinco codigos errados invalidam o codigo certo" do
    code = users(:one).send_password_reset_code
    wrong = code == "000000" ? "111111" : "000000"

    User::PASSWORD_RESET_CODE_MAX_ATTEMPTS.times { reset_with(wrong) }
    reset_with(code)

    assert_response :unprocessable_entity
    assert_select "[data-field-error=reset_code]", text: INVALID_CODE
    assert_not users(:one).reload.valid_password?("novasenha123")
  end

  test "pedir um codigo novo invalida o anterior" do
    old_code = users(:one).send_password_reset_code
    new_code = old_code
    new_code = users(:one).send_password_reset_code while new_code == old_code

    reset_with(old_code)
    assert_response :unprocessable_entity

    reset_with(new_code)
    assert users(:one).reload.valid_password?("novasenha123")
  end

  test "conta do Google nao redefine senha por codigo" do
    users(:two).update!(provider: "google_oauth2", uid: "123")

    reset_with("123456", email: "two@example.com")

    assert_response :unprocessable_entity
    assert_select "[data-field-error=reset_code]", text: INVALID_CODE
  end

  test "e-mail sem conta da o mesmo erro de codigo invalido" do
    reset_with("123456", email: "ninguem@example.com")

    assert_response :unprocessable_entity
    assert_select "[data-field-error=reset_code]", text: INVALID_CODE
  end

  test "codigo em branco mostra o erro no campo" do
    reset_with("")

    assert_response :unprocessable_entity
    assert_select "[data-field-error=reset_code]", text: "Código não pode ficar em branco"
  end

  test "senha nova curta ou diferente da confirmacao mostra erro no campo sem gastar o codigo" do
    code = users(:one).send_password_reset_code

    reset_with(code, password: "123", confirmation: "456")

    assert_response :unprocessable_entity
    assert_includes response.body, "Senha é muito curta: use pelo menos 6 caracteres"
    assert_includes response.body, "Confirmação de senha não é igual a Senha"

    reset_with(code)
    assert users(:one).reload.valid_password?("novasenha123")
  end
end
