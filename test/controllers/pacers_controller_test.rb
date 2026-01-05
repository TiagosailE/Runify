require "test_helper"

class PacersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get pacers_index_url
    assert_response :success
  end

  test "should get new" do
    get pacers_new_url
    assert_response :success
  end

  test "should get create" do
    get pacers_create_url
    assert_response :success
  end

  test "should get show" do
    get pacers_show_url
    assert_response :success
  end

  test "should get join" do
    get pacers_join_url
    assert_response :success
  end

  test "should get leave" do
    get pacers_leave_url
    assert_response :success
  end
end
