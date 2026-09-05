require "test_helper"

class Admin::AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
  end

  test "visitante nao autenticado e mandado para o login" do
    get admin_audit_logs_path
    assert_redirected_to new_user_session_path
  end

  test "usuario comum nao entra na auditoria" do
    sign_in users(:one)
    get admin_audit_logs_path

    assert_redirected_to dashboard_path
  end

  test "admin ve as acoes registradas" do
    AdminAuditLog.create!(
      admin: @admin,
      target_user: users(:one),
      action: "plan_cancel",
      details: "plano #42"
    )

    sign_in @admin
    get admin_audit_logs_path

    assert_response :success
    assert_match "Plano de treino cancelado", response.body
    assert_match "plano #42", response.body
    assert_match users(:one).email, response.body
  end

  test "auditoria vazia nao quebra a tela" do
    sign_in @admin
    get admin_audit_logs_path

    assert_response :success
    assert_match "Nenhuma ação registrada ainda.", response.body
  end
end
