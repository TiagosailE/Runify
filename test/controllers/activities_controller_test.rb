require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get new" do
    get new_activity_url
    assert_response :success
  end

  test "create saves a manual activity and redirects to history" do
    assert_difference "users(:one).activities.count", 1 do
      post activities_url, params: {
        activity: { name: "Corrida no parque", start_date: Date.current, distance_km: "5.2",
                    duration_hours: "0", duration_minutes: "28", duration_seconds: "30" }
      }
    end

    assert_redirected_to history_path
    activity = users(:one).activities.order(:created_at).last
    assert_equal "manual", activity.source
    assert_equal "Run", activity.sport_type
    assert_equal 5200, activity.distance
    assert_equal 1710, activity.duration
  end

  test "create defaults the name when left blank" do
    post activities_url, params: {
      activity: { name: "", start_date: Date.current, distance_km: "3",
                  duration_hours: "0", duration_minutes: "20", duration_seconds: "0" }
    }

    assert_equal "Corrida", users(:one).activities.order(:created_at).last.name
  end

  test "create re-renders the form when distance is missing" do
    assert_no_difference "Activity.count" do
      post activities_url, params: {
        activity: { name: "Sem distância", start_date: Date.current, distance_km: "0",
                    duration_hours: "0", duration_minutes: "10", duration_seconds: "0" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "destroy removes the caller's activity" do
    activity = users(:one).activities.create!(
      name: "A apagar", sport_type: "Run", distance: 1000, duration: 300,
      moving_time: 300, start_date: Time.current, source: "manual"
    )

    assert_difference "Activity.count", -1 do
      delete activity_url(activity)
    end

    assert_redirected_to history_path
  end

  test "destroy does not reach another user's activity" do
    other_activity = users(:two).activities.create!(
      name: "De outro usuário", sport_type: "Run", distance: 1000, duration: 300,
      moving_time: 300, start_date: Time.current, source: "manual"
    )

    assert_no_difference "Activity.count" do
      delete activity_url(other_activity)
    end

    assert_response :not_found
  end
end
