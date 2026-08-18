require "test_helper"
require "ostruct"

class StravaControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  def stub_oauth_token(athlete_id)
    fake_athlete = OpenStruct.new(id: athlete_id, firstname: "Runner")
    fake_token_response = OpenStruct.new(
      access_token: "atok",
      refresh_token: "rtok",
      expires_at: 1.day.from_now.to_i,
      athlete: fake_athlete
    )
    fake_oauth = Object.new
    fake_oauth.define_singleton_method(:oauth_token) { |*_args, **_kwargs| fake_token_response }
    fake_oauth
  end

  def state_from_redirect
    Rack::Utils.parse_nested_query(URI(response.redirect_url).query)["state"]
  end

  test "should get connect" do
    get strava_connect_url
    assert_response :redirect
    assert_match(/state=/, response.redirect_url)
  end

  test "connect stores a fresh state nonce and the connecting user in session" do
    get strava_connect_url
    assert_equal users(:one).id, session[:strava_connecting_user_id]
    assert session[:strava_oauth_state].present?
  end

  test "callback without a prior connect visit is rejected" do
    get strava_callback_url(state: "whatever", code: "abc")
    assert_redirected_to dashboard_path
    assert_equal "error", flash[:toast][:type]
  end

  test "callback with a state that does not match the session is rejected" do
    get strava_connect_url

    get strava_callback_url(state: "tampered-state", code: "abc")

    assert_redirected_to dashboard_path
    assert_equal "error", flash[:toast][:type]
    assert_equal "1000001", users(:one).reload.strava_integration.strava_athlete_id
  end

  test "callback creates the integration and syncs on first successful connect" do
    get strava_connect_url
    state = state_from_redirect

    fake_api = Object.new
    fake_api.define_singleton_method(:athlete_activities) { |*_args, **_kwargs| [] }

    Strava::OAuth::Client.stub :new, stub_oauth_token(555_555) do
      Strava::Api::Client.stub :new, fake_api do
        get strava_callback_url(state: state, code: "validcode")
      end
    end

    assert_redirected_to dashboard_path
    assert_equal "success", flash[:toast][:type]

    integration = StravaIntegration.find_by(strava_athlete_id: "555555")
    assert_equal users(:one).id, integration.user_id
  end

  test "callback blocks when the athlete is already connected to a different user" do
    other_integration = StravaIntegration.create!(
      user: users(:two),
      strava_athlete_id: "777777",
      access_token: "x",
      refresh_token: "y",
      token_expires_at: 1.day.from_now,
      active: true
    )

    get strava_connect_url
    state = state_from_redirect

    Strava::OAuth::Client.stub :new, stub_oauth_token(777_777) do
      get strava_callback_url(state: state, code: "validcode")
    end

    assert_redirected_to dashboard_path
    assert_equal "error", flash[:toast][:type]
    assert_equal users(:two).id, other_integration.reload.user_id
    assert_equal "1000001", users(:one).reload.strava_integration.strava_athlete_id
  end

  test "callback succeeds even when the first sync fails" do
    get strava_connect_url
    state = state_from_redirect

    fake_api = Object.new
    fake_api.define_singleton_method(:athlete_activities) { |*_args, **_kwargs| raise "Forbidden" }

    Strava::OAuth::Client.stub :new, stub_oauth_token(888_888) do
      Strava::Api::Client.stub :new, fake_api do
        get strava_callback_url(state: state, code: "validcode")
      end
    end

    assert_redirected_to dashboard_path
    assert_equal "success", flash[:toast][:type]
    assert users(:one).reload.strava_integration.present?
  end

  test "should get disconnect" do
    delete strava_disconnect_url
    assert_redirected_to dashboard_path
  end
end
