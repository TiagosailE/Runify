require "test_helper"

class PacersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get pacers_url
    assert_response :success
  end

  test "should get new" do
    get new_pacer_url
    assert_response :success
  end

  test "should get create" do
    post pacers_url, params: {
      squad: {
        name: "New Squad",
        description: "Test squad",
        challenge_duration: 7,
        challenge_start: Date.today,
        challenge_end: Date.today + 7.days
      }
    }
    assert_response :redirect
  end

  test "should get show" do
    get pacer_url(squads(:one))
    assert_response :success
  end

  test "should get join" do
    post join_pacer_url(squads(:two)), params: { code: squads(:two).squad_code }
    assert_response :redirect
  end

  test "should get leave" do
    sign_out users(:one)
    sign_in users(:two)

    delete leave_pacer_url(squads(:two))
    assert_response :redirect
  end
end
