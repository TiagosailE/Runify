require "test_helper"

class HistoryControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get history_url
    assert_response :success
  end

  test "rotula caminhada na esteira com a inclinacao" do
    users(:one).activities.create!(
      name: "Caminhada", sport_type: "Walk", treadmill: true, incline_percent: 6, distance: 4000,
      duration: 2700, moving_time: 2700, start_date: Time.current, source: "manual"
    )

    get history_url

    assert_includes response.body, "Caminhada na esteira, inclinação 6%"
  end
end
