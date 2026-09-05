require "test_helper"

class AdminAuditLogTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @target = users(:one)
  end

  test "aceita uma acao conhecida" do
    log = AdminAuditLog.new(admin: @admin, target_user: @target, action: "strava_disconnect")
    assert log.valid?
  end

  test "rejeita acao desconhecida" do
    log = AdminAuditLog.new(admin: @admin, target_user: @target, action: "apagar_tudo")

    assert_not log.valid?
    assert_includes log.errors[:action], "não é uma ação conhecida"
  end

  test "exige administrador e usuario alvo" do
    log = AdminAuditLog.new(action: "plan_cancel")

    assert_not log.valid?
    assert log.errors[:admin].any?
    assert log.errors[:target_user].any?
  end

  test "traduz a acao para rotulo legivel" do
    log = AdminAuditLog.new(action: "password_reset_sent")
    assert_equal "E-mail de redefinicao de senha enviado", log.action_label
  end

  test "newest_first devolve a acao mais recente primeiro" do
    older = AdminAuditLog.create!(admin: @admin, target_user: @target, action: "plan_cancel", created_at: 2.days.ago)
    newer = AdminAuditLog.create!(admin: @admin, target_user: @target, action: "plan_cancel", created_at: 1.hour.ago)

    assert_equal [ newer, older ], AdminAuditLog.newest_first.to_a
  end

  # A trilha e sobre o usuario, entao some com ele quando ele exerce o direito
  # de eliminacao (LGPD Art. 18 VI) -- e, mais concretamente, a FK nao pode
  # bloquear SettingsController#delete_account.
  test "e apagada junto com o usuario alvo" do
    AdminAuditLog.create!(admin: @admin, target_user: @target, action: "plan_cancel")

    assert_difference "AdminAuditLog.count", -1 do
      @target.destroy!
    end
  end

  test "e apagada junto com o administrador" do
    AdminAuditLog.create!(admin: @admin, target_user: @target, action: "plan_cancel")

    assert_difference "AdminAuditLog.count", -1 do
      @admin.destroy!
    end
  end
end
