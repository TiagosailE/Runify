require "test_helper"
require "ostruct"

class SyncStravaActivitiesJobTest < ActiveJob::TestCase
  test "sync_user_activities creates new activities and reports counts" do
    user = users(:one)
    integration = StravaIntegration.create!(
      user: user, strava_athlete_id: "1234", access_token: "a", refresh_token: "r",
      token_expires_at: 1.day.from_now, active: true
    )

    fake_activity = OpenStruct.new(
      id: 42, name: "Corrida", sport_type: "Run", distance: 5000.0,
      elapsed_time: 1500, moving_time: 1400, average_speed: 3.3,
      start_date: Time.current, to_h: { id: 42 }
    )
    fake_api = Object.new
    fake_api.define_singleton_method(:athlete_activities) { |*_args, **_kwargs| [ fake_activity ] }

    result = Strava::Api::Client.stub :new, fake_api do
      SyncStravaActivitiesJob.new.sync_user_activities(user)
    end

    assert_equal 1, result[:new_count]
    assert_equal 0, result[:updated_count]
    assert_nil result[:error]
    assert user.activities.exists?(strava_activity_id: "42")
    assert integration.reload.last_sync_at.present?
  end

  test "sync_user_activities returns the error instead of raising when the API call fails" do
    user = users(:one)
    StravaIntegration.create!(
      user: user, strava_athlete_id: "1234", access_token: "a", refresh_token: "r",
      token_expires_at: 1.day.from_now, active: true
    )

    fake_api = Object.new
    fake_api.define_singleton_method(:athlete_activities) { |*_args, **_kwargs| raise "Forbidden" }

    result = Strava::Api::Client.stub :new, fake_api do
      SyncStravaActivitiesJob.new.sync_user_activities(user)
    end

    assert_equal 0, result[:new_count]
    assert result[:error].present?
  end

  test "sync_user_activities is a no-op for users without an active strava connection" do
    user = users(:two)
    result = SyncStravaActivitiesJob.new.sync_user_activities(user)
    assert_equal({ new_count: 0, updated_count: 0, error: nil }, result)
  end
end
