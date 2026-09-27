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

  test "step2 persists weight and height immediately, without needing to finish the flow" do
    post onboarding_step2_url, params: { weight: 70, height: 175, birth_date: "1995-05-20" }

    assert_redirected_to onboarding_step2_view_path
    user = users(:one).reload
    assert_equal 70, user.weight
    assert_equal 175, user.height
    assert_equal Date.parse("1995-05-20"), user.birth_date
  end

  test "sign in sends user back to step1 when weight is still missing" do
    sign_out users(:one)

    post user_session_url, params: { user: { email: users(:one).email, password: "password1234" } }

    assert_redirected_to onboarding_step1_path
  end

  test "sign in sends user to step2 (not step1) when weight is set but goal is missing" do
    user = users(:one)
    user.update!(weight: 70, height: 175)
    sign_out user

    post user_session_url, params: { user: { email: user.email, password: "password1234" } }

    assert_redirected_to onboarding_step2_view_path
  end
end
