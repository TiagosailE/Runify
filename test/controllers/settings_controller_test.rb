require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get settings_index_url
    assert_response :success
  end

  test "should get update_password" do
    get settings_update_password_url
    assert_response :success
  end

  test "should get toggle_theme" do
    get settings_toggle_theme_url
    assert_response :success
  end
end
