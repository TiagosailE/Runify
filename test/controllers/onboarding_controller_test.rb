require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get step1" do
    get onboarding_step1_url
    assert_response :success
  end

  test "should get step2" do
    get onboarding_step2_url
    assert_response :success
  end

  test "should get complete" do
    post onboarding_complete_url
    assert_redirected_to dashboard_path
  end
end
