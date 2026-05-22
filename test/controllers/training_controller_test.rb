require "test_helper"

class TrainingControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get training_index_url
    assert_response :success
  end

  test "should get show" do
    get training_show_url(workouts(:one))
    assert_response :success
  end

  test "should get complete" do
    post training_complete_url(workouts(:one))
    assert_response :success
  end

  test "should get feedback" do
    post training_feedback_url(workouts(:one)), params: { difficulty: "medium", notes: "ok" }
    assert_response :success
  end
end
