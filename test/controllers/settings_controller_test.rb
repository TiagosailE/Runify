require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get settings_url
    assert_response :success
  end

  test "should get update_password" do
    post update_password_settings_url, params: {
      current_password: "password123",
      new_password: "newpassword123",
      password_confirmation: "newpassword123"
    }
    assert_redirected_to settings_path
  end

  test "should get toggle_theme" do
    post toggle_theme_settings_url
    assert_response :success
  end
end
