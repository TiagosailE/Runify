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

  test "export_data devolve JSON com os dados do usuario" do
    user = users(:one)
    before_count = user.activities.count
    user.activities.create!(
      name: "Corrida", sport_type: "Run", distance: 5000, duration: 1800,
      moving_time: 1800, start_date: 2.days.ago, source: "manual"
    )

    get export_data_settings_url

    assert_response :success
    assert_equal "application/json", @response.media_type

    body = JSON.parse(@response.body)
    assert body["account"]["email"].present?
    assert_equal before_count + 1, body["activities"].size
    assert body.key?("strava_connected")
  end

  test "export_data nao inclui senha nem tokens de autenticacao" do
    get export_data_settings_url

    body = @response.body
    assert_not_includes body, users(:one).encrypted_password
    assert_not_includes body, "encrypted_password"
    assert_not_includes body, "reset_password_token"
  end
end
