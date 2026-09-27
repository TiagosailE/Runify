require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "tipo fora da lista permitida e invalido" do
    notification = Notification.new(
      user: users(:one), title: "Teste", message: "Teste",
      notification_type: "tipo_inventado", sent_at: Time.current
    )

    assert_not notification.valid?
    assert_includes notification.errors[:notification_type], "não está incluído na lista"
  end

  test "sync_reminder continua um tipo valido para notificacao antiga" do
    notification = Notification.new(
      user: users(:one), title: "Teste", message: "Teste",
      notification_type: "sync_reminder", sent_at: Time.current
    )

    assert notification.valid?
  end

  test "mark_as_read marca como lida" do
    notification = users(:one).notifications.create!(
      title: "Teste", message: "Teste", notification_type: "congratulations",
      sent_at: Time.current, read: false
    )

    notification.mark_as_read!

    assert notification.reload.read?
  end

  test "unread exclui as notificacoes ja lidas" do
    user = users(:one)
    unread = user.notifications.create!(
      title: "Nao lida", message: "Teste", notification_type: "congratulations",
      sent_at: Time.current, read: false
    )
    read = user.notifications.create!(
      title: "Lida", message: "Teste", notification_type: "congratulations",
      sent_at: Time.current, read: true
    )

    assert_includes user.notifications.unread, unread
    assert_not_includes user.notifications.unread, read
  end
end
