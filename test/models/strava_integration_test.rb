require "test_helper"
require "ostruct"

class StravaIntegrationTest < ActiveSupport::TestCase
  test "refresh_token! updates token fields" do
    user = users(:one)
    integration = StravaIntegration.create!(user: user, access_token: 'old', refresh_token: 'rtok', token_expires_at: 1.minute.ago, active: true)

    fake_oauth = Object.new
    def fake_oauth.oauth_token(_opts = {})
      OpenStruct.new(access_token: 'new_access', refresh_token: 'new_refresh', expires_at: (Time.current + 1.day).to_i)
    end

    Strava::OAuth::Client.stub :new, fake_oauth do
      integration.refresh_token!
    end

    integration.reload
    assert_equal 'new_access', integration.access_token
    assert_equal 'new_refresh', integration.refresh_token
    assert integration.token_expires_at > Time.current
  end

  test "fetch_recent_activities uses Strava::Api::Client" do
    user = users(:one)
    integration = StravaIntegration.create!(user: user, access_token: 'token', refresh_token: 'rtok', token_expires_at: Time.current + 1.day, active: true)

    fake_api = Object.new
    def fake_api.athlete_activities(_opts = {})
      [OpenStruct.new(id: 123, name: 'Run')]
    end

    Strava::Api::Client.stub :new, fake_api do
      activities = integration.fetch_recent_activities(per_page: 5)
      assert_equal 1, activities.length
      assert_equal 123, activities.first.id
    end
  end
end
