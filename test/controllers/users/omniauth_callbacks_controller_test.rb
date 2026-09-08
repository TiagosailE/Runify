require "test_helper"

# Login com Google: e-mail existente vincula e loga direto (o Google ja
# verificou o e-mail, entao o vinculo automatico e seguro -- decisao [E]
# do Tiago); e-mail novo nao cria conta na hora, guarda os dados na sessao
# e manda para o aceite de termos (Users::GoogleSignupsController).
class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup { OmniAuth.config.test_mode = true }

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  def mock_google_auth(email:, uid: "google-uid-123", name: "Runner Teste")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: OmniAuth::AuthHash::InfoHash.new(email: email, name: name)
    )
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
  end

  test "e-mail existente vincula provider/uid e loga direto" do
    mock_google_auth(email: users(:one).email, uid: "existing-uid")

    get user_google_oauth2_omniauth_callback_path

    assert_redirected_to onboarding_step1_path
    users(:one).reload
    assert_equal "google_oauth2", users(:one).provider
    assert_equal "existing-uid", users(:one).uid
  end

  test "nao sobrescreve um vinculo ja existente" do
    users(:one).update!(provider: "google_oauth2", uid: "original-uid")
    mock_google_auth(email: users(:one).email, uid: "another-uid")

    get user_google_oauth2_omniauth_callback_path

    assert_equal "original-uid", users(:one).reload.uid
  end

  test "e-mail novo guarda os dados na sessao e manda para o consentimento, sem criar a conta" do
    mock_google_auth(email: "novo-por-google@example.com", uid: "new-uid", name: "Novo Usuario")

    get user_google_oauth2_omniauth_callback_path

    assert_redirected_to new_google_signup_path
    assert_equal "new-uid", session[:google_pending_signup]["uid"]
    assert_equal "novo-por-google@example.com", session[:google_pending_signup]["email"]
    assert_equal "Novo Usuario", session[:google_pending_signup]["name"]
    assert_nil User.find_by(email: "novo-por-google@example.com")
  end
end
