require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  GENERIC_MESSAGE = "Se o e-mail estiver cadastrado, você receberá as instruções em alguns minutos.".freeze

  test "tela de login tem o link de esqueci minha senha" do
    get new_user_session_path

    assert_select "a[href='#{new_user_password_path}']", text: "Esqueci minha senha"
  end

  test "tela de pedir recuperacao esta em portugues" do
    get new_user_password_path

    assert_response :success
    assert_includes response.body, "Esqueceu sua senha?"
    assert_select "input[type=submit][value='Enviar instruções']"
  end

  test "conta com senha recebe o link de redefinicao" do
    assert_emails 1 do
      post user_password_path, params: { user: { email: "ONE@example.com " } }
    end

    assert_redirected_to new_user_session_path
    assert_equal GENERIC_MESSAGE, flash[:toast][:message]

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "one@example.com" ], mail.to
    assert_includes mail.body.encoded, "reset_password_token="
    assert_includes mail.body.encoded, "Redefinir minha senha"
    assert users(:one).reload.reset_password_token.present?
  end

  test "conta do Google recebe orientacao para entrar pelo Google, sem link de redefinicao" do
    users(:two).update!(provider: "google_oauth2", uid: "123")

    assert_emails 1 do
      post user_password_path, params: { user: { email: "two@example.com" } }
    end

    assert_equal GENERIC_MESSAGE, flash[:toast][:message]
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "two@example.com" ], mail.to
    assert_includes mail.body.encoded, "Continuar com Google"
    assert_includes mail.body.encoded, "accounts.google.com/signin/recovery"
    assert_not_includes mail.body.encoded, "reset_password_token"
    assert_nil users(:two).reload.reset_password_token
  end

  test "e-mail nao cadastrado recebe a mesma mensagem generica e nenhum e-mail sai" do
    assert_no_emails do
      post user_password_path, params: { user: { email: "ninguem@example.com" } }
    end

    assert_redirected_to new_user_session_path
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

    Devise::Mailer.stub(:reset_password_instructions, failing) do
      post user_password_path, params: { user: { email: "one@example.com" } }
    end

    assert_redirected_to new_user_session_path
    assert_equal GENERIC_MESSAGE, flash[:toast][:message]
  end

  test "link valido define a nova senha e entra na conta" do
    users(:one).update!(weight: 70, goal: "Correr 5km")
    token = users(:one).send_reset_password_instructions

    get edit_user_password_path(reset_password_token: token)
    assert_response :success
    assert_includes response.body, "Nova senha"

    put user_password_path, params: {
      user: { reset_password_token: token, password: "novasenha123", password_confirmation: "novasenha123" }
    }

    assert_redirected_to dashboard_path
    assert users(:one).reload.valid_password?("novasenha123")
  end

  test "link usado uma vez nao funciona de novo" do
    token = users(:one).send_reset_password_instructions
    put user_password_path, params: {
      user: { reset_password_token: token, password: "novasenha123", password_confirmation: "novasenha123" }
    }
    sign_out :user

    put user_password_path, params: {
      user: { reset_password_token: token, password: "outrasenha123", password_confirmation: "outrasenha123" }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Link de redefinição não é válido ou já foi usado"
    assert users(:one).reload.valid_password?("novasenha123")
  end

  test "link expira em uma hora" do
    token = users(:one).send_reset_password_instructions

    travel 61.minutes do
      put user_password_path, params: {
        user: { reset_password_token: token, password: "novasenha123", password_confirmation: "novasenha123" }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Link de redefinição expirou, solicite um novo"
    assert_not users(:one).reload.valid_password?("novasenha123")
  end

  test "senha nova curta ou diferente da confirmacao mostra erro no campo" do
    token = users(:one).send_reset_password_instructions

    put user_password_path, params: {
      user: { reset_password_token: token, password: "123", password_confirmation: "456" }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Senha é muito curta: use pelo menos 6 caracteres"
    assert_includes response.body, "Confirmação de senha não é igual a Senha"
  end
end
