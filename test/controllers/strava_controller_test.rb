require "test_helper"

class StravaControllerTest < ActionDispatch::IntegrationTest
  test "should get connect" do
    get strava_connect_url
    assert_response :success
  end

  test "should get callback" do
    get strava_callback_url
    assert_response :success
  end

  test "should get disconnect" do
    get strava_disconnect_url
    assert_response :success
  end
end
