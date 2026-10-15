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

  test "registra caminhada na esteira com inclinacao" do
    post activities_url, params: {
      activity: { name: "", start_date: Date.current, sport_type: "Walk", treadmill: "1",
                  distance_km: "4", incline_percent: "6", speed_kmh: "",
                  duration_hours: "0", duration_minutes: "45", duration_seconds: "0" }
    }

    activity = users(:one).activities.order(:created_at).last
    assert_redirected_to history_path
    assert_equal "Walk", activity.sport_type
    assert activity.treadmill?
    assert_equal 6, activity.incline_percent
    assert_equal 4000, activity.distance
    assert_equal "Caminhada na esteira", activity.name
  end

  test "na esteira sem distancia, calcula a distancia pela velocidade media" do
    post activities_url, params: {
      activity: { start_date: Date.current, sport_type: "Run", treadmill: "1",
                  distance_km: "", speed_kmh: "10", incline_percent: "1",
                  duration_hours: "0", duration_minutes: "30", duration_seconds: "0" }
    }

    activity = users(:one).activities.order(:created_at).last
    assert_equal 5000, activity.distance
    assert_equal "Corrida na esteira", activity.name
  end

  test "distancia informada prevalece sobre a velocidade" do
    post activities_url, params: {
      activity: { start_date: Date.current, sport_type: "Run", treadmill: "1",
                  distance_km: "5.3", speed_kmh: "10",
                  duration_hours: "0", duration_minutes: "30", duration_seconds: "0" }
    }

    assert_equal 5300, users(:one).activities.order(:created_at).last.distance
  end

  test "na rua a inclinacao e a velocidade sao ignoradas" do
    post activities_url, params: {
      activity: { start_date: Date.current, sport_type: "Run", treadmill: "0",
                  distance_km: "", speed_kmh: "10", incline_percent: "5",
                  duration_hours: "0", duration_minutes: "30", duration_seconds: "0" }
    }

    assert_response :unprocessable_entity
    assert_nil users(:one).activities.find_by(incline_percent: 5)
  end

  test "modalidade desconhecida vira corrida" do
    post activities_url, params: {
      activity: { start_date: Date.current, sport_type: "Ride", distance_km: "10",
                  duration_hours: "0", duration_minutes: "30", duration_seconds: "0" }
    }

    assert_equal "Run", users(:one).activities.order(:created_at).last.sport_type
  end

  test "formulario oferece corrida, caminhada, rua e esteira" do
    get new_activity_url

    assert_select "input[type=radio][name='activity[sport_type]'][value=Run]"
    assert_select "input[type=radio][name='activity[sport_type]'][value=Walk]"
    assert_select "input[type=radio][name='activity[treadmill]'][value='1']"
    assert_select "input[name='activity[incline_percent]']"
    assert_select "input[name='activity[speed_kmh]']"
  end
end
