require "test_helper"

# Publicas de proposito: precisam ser legiveis ANTES do cadastro, ja que o
# checkbox de consentimento do formulario linka pra elas.
class PagesControllerTest < ActionDispatch::IntegrationTest
  test "privacidade acessivel sem login" do
    get privacy_policy_url
    assert_response :success
  end

  test "termos acessivel sem login" do
    get terms_of_use_url
    assert_response :success
  end

  test "sobre acessivel sem login" do
    get about_page_url
    assert_response :success
  end
end
