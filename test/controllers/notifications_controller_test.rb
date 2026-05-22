require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get notifications_url
    assert_response :success
  end

  test "should get mark_as_read" do
    post mark_as_read_notification_url(notifications(:one))
    assert_redirected_to notifications_path
  end
end
