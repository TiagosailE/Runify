require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "viewport nao bloqueia zoom" do
    get root_url

    assert_no_match(/user-scalable=no/, response.body)
    assert_no_match(/maximum-scale/, response.body)
  end
end
