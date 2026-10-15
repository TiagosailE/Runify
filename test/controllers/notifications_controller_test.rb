require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get notifications_url
    assert_response :success
  end

  test "mostra o tempo relativo em portugues" do
    notifications(:one).update_column(:sent_at, 5.minutes.ago)
    notifications(:one).user.notifications.where.not(id: notifications(:one).id).delete_all

    get notifications_url

    assert_response :success
    assert_includes response.body, "há 5 minutos"
    assert_not_includes response.body.downcase, "translation missing"
  end

  test "should get mark_as_read" do
    post mark_as_read_notification_url(notifications(:one))
    assert_redirected_to notifications_path
  end
end
