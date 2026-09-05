require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  # --- Controle de acesso ---------------------------------------------------

  test "visitante nao autenticado e mandado para o login" do
    get admin_users_path
    assert_redirected_to new_user_session_path
  end

  test "usuario comum nao entra no painel" do
    sign_in users(:one)
    get admin_users_path

    assert_redirected_to dashboard_path
    toast = flash[:toast]
    assert_equal "Acesso restrito.", toast[:message] || toast["message"]
  end

  test "usuario comum nao abre a ficha de outro usuario" do
    sign_in users(:two)
    get admin_user_path(@user)

    assert_redirected_to dashboard_path
  end

  test "usuario comum nao executa acao de escrita" do
    sign_in users(:two)

    assert_no_difference "AdminAuditLog.count" do
      post send_password_reset_admin_user_path(@user)
    end

    assert_redirected_to dashboard_path
  end

  test "admin abre a listagem" do
    sign_in @admin
    get admin_users_path

    assert_response :success
    assert_match @user.email, response.body
    assert_select "a[href=?]", admin_user_path(@user)
  end

  # --- Entrada no painel ----------------------------------------------------

  test "login de admin cai direto no painel" do
    post user_session_path, params: { user: { email: @admin.email, password: "password123" } }

    assert_redirected_to admin_root_path
  end

  test "login de usuario comum segue o fluxo normal de onboarding" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_redirected_to onboarding_step1_path
  end

  test "admin abre a ficha de um usuario" do
    sign_in @admin
    get admin_user_path(@user)

    assert_response :success
  end

  # --- Listagem -------------------------------------------------------------

  test "busca filtra por e-mail" do
    sign_in @admin
    get admin_users_path(q: "two@example")

    assert_response :success
    assert_match "two@example.com", response.body
    assert_no_match "one@example.com", response.body
  end

  test "busca sem resultado nao quebra a tela" do
    sign_in @admin
    get admin_users_path(q: "ninguem-com-esse-email")

    assert_response :success
    assert_match "Nenhum usuário encontrado", response.body
  end

  # --- A ficha nao expoe dado pessoal ---------------------------------------

  test "ficha nao mostra peso, altura, nascimento nem historico de lesao" do
    @user.update_columns(
      weight: 71,
      height: 181,
      birth_date: Date.new(1990, 5, 20),
      injury_history: "Tendinite no joelho direito em 2024"
    )

    sign_in @admin
    get admin_user_path(@user)

    assert_response :success
    assert_no_match "Tendinite no joelho direito", response.body
    assert_no_match(/\b181\b/, response.body)
    assert_no_match "20/05/1990", response.body
  end

  # --- Acoes de suporte -----------------------------------------------------

  test "desconectar strava remove a integracao e registra auditoria" do
    integration = strava_integrations(:one)
    target = integration.user
    sign_in @admin

    assert_difference "StravaIntegration.count", -1 do
      assert_difference "AdminAuditLog.count", 1 do
        delete disconnect_strava_admin_user_path(target)
      end
    end

    assert_redirected_to admin_user_path(target)

    log = AdminAuditLog.newest_first.first
    assert_equal "strava_disconnect", log.action
    assert_equal @admin, log.admin
    assert_equal target, log.target_user
  end

  test "desconectar strava de quem nao tem avisa e nao registra nada" do
    sign_in @admin
    target = users(:two)
    target.strava_integration&.destroy!

    assert_no_difference "AdminAuditLog.count" do
      delete disconnect_strava_admin_user_path(target)
    end

    assert_redirected_to admin_user_path(target)
    assert_equal "Esse usuário não tem Strava conectado.", flash[:alert]
  end

  test "cancelar plano ativo muda o status e registra auditoria" do
    plan = training_plans(:one)
    plan.update!(status: "active")
    target = plan.user
    sign_in @admin

    assert_difference "AdminAuditLog.count", 1 do
      post cancel_training_plan_admin_user_path(target)
    end

    assert_equal "cancelled", plan.reload.status
    assert_equal "plan_cancel", AdminAuditLog.newest_first.first.action
  end

  test "cancelar plano sem plano ativo avisa e nao registra nada" do
    target = users(:two)
    target.training_plans.update_all(status: "cancelled")
    sign_in @admin

    assert_no_difference "AdminAuditLog.count" do
      post cancel_training_plan_admin_user_path(target)
    end

    assert_equal "Esse usuário não tem plano ativo.", flash[:alert]
  end

  test "enviar redefinicao de senha dispara o e-mail e registra auditoria" do
    sign_in @admin

    assert_difference "AdminAuditLog.count", 1 do
      assert_emails 1 do
        post send_password_reset_admin_user_path(@user)
      end
    end

    assert_redirected_to admin_user_path(@user)
    assert_equal "password_reset_sent", AdminAuditLog.newest_first.first.action
    assert @user.reload.reset_password_token.present?
  end

  test "falha no envio de e-mail vira aviso, nao erro 500" do
    sign_in @admin

    broken = User.find(@user.id)
    broken.define_singleton_method(:send_reset_password_instructions) do
      raise StandardError, "Resend fora do ar"
    end

    User.stub(:find, broken) do
      assert_no_difference "AdminAuditLog.count" do
        post send_password_reset_admin_user_path(@user)
      end
    end

    assert_redirected_to admin_user_path(@user)
    assert_match "Resend fora do ar", flash[:alert]
  end
end
