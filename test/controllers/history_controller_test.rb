require "test_helper"

class HistoryControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get history_url
    assert_response :success
  end
end
