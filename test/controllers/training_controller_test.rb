require "test_helper"

class TrainingControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get training_index_url
    assert_response :success
  end

  test "should get show" do
    get training_show_url
    assert_response :success
  end

  test "should get complete" do
    get training_complete_url
    assert_response :success
  end

  test "should get feedback" do
    get training_feedback_url
    assert_response :success
  end
end
