require "test_helper"

class StravaControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get connect" do
    get strava_connect_url
    assert_response :redirect
  end

  test "should get callback" do
    get strava_callback_url
    assert_redirected_to dashboard_path
  end

  test "should get disconnect" do
    delete strava_disconnect_url
    assert_redirected_to dashboard_path
  end
end
