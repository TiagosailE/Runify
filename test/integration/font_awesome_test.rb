require "test_helper"

class FontAwesomeTest < ActionDispatch::IntegrationTest
  test "layout nao referencia cdnjs e a CSP nao libera esse host" do
    sign_in users(:one)
    get dashboard_url

    assert_response :success
    assert_no_match "cdnjs", @response.body
    assert_no_match "cdnjs", @response.headers["Content-Security-Policy"]
  end

  test "o css do Font Awesome e servido pelo app e aponta pros webfonts digeridos" do
    asset = Rails.application.assets.load_path.find("font-awesome/css/all.min.css")
    assert asset, "font-awesome/css/all.min.css nao encontrado no load path do Propshaft"

    compiled = asset.compiled_content
    assert_match %r{/assets/font-awesome/webfonts/fa-solid-900-[0-9a-f]+\.woff2}, compiled
    assert_no_match "../webfonts", compiled
  end
end
