require "test_helper"

class ProfileControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get profile_url
    assert_response :success
  end

  test "should get update" do
    patch profile_update_url, params: { user: { username: "Updated User", weight: 70, height: 175, goal: "5k" } }
    assert_redirected_to profile_path
  end
end
