require "test_helper"
require "ostruct"

class RefreshStravaTokensJobTest < ActiveJob::TestCase
  test "refreshes tokens for integrations needing refresh" do
    user = users(:one)
    integration = StravaIntegration.create!(user: user, access_token: 'old', refresh_token: 'rtok', token_expires_at: 1.minute.ago, active: true)

    fake_oauth = Object.new
    def fake_oauth.oauth_token(_opts = {})
      OpenStruct.new(access_token: 'new_access', refresh_token: 'new_refresh', expires_at: (Time.current + 1.day).to_i)
    end

    Strava::OAuth::Client.stub :new, fake_oauth do
      RefreshStravaTokensJob.perform_now
    end

    integration.reload
    assert_equal 'new_access', integration.access_token
    assert_equal 'new_refresh', integration.refresh_token
  end
end
