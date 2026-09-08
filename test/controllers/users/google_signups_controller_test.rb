require "test_helper"

# Tela intermediaria entre o callback do Google e a criacao da conta: sem
# ela, uma conta nova via Google existiria sem ter passado pelo mesmo
# aceite de termos/privacidade exigido no cadastro comum (LGPD).
class Users::GoogleSignupsControllerTest < ActionDispatch::IntegrationTest
  setup { OmniAuth.config.test_mode = true }

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  def start_pending_google_signup(email:, uid: "new-uid", name: "Novo Usuario")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: OmniAuth::AuthHash::InfoHash.new(email: email, name: name)
    )
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
    get user_google_oauth2_omniauth_callback_path
  end

  test "sem cadastro pendente na sessao redireciona para o login" do
    get new_google_signup_path
    assert_redirected_to new_user_session_path
  end

  test "aceitar os termos cria a conta, vincula o Google e loga" do
    start_pending_google_signup(email: "aceita@example.com", uid: "uid-aceita", name: "Corredora Nova")

    assert_difference "User.count", 1 do
      post google_signup_path, params: { user: { terms_accepted: "1" } }
    end

    user = User.find_by(email: "aceita@example.com")
    assert_equal "google_oauth2", user.provider
    assert_equal "uid-aceita", user.uid
    assert_equal "Corredora Nova", user.username
    assert user.terms_accepted_at.present?
    assert_redirected_to onboarding_step1_path
  end

  test "sem aceitar os termos nao cria a conta" do
    start_pending_google_signup(email: "recusa@example.com", uid: "uid-recusa")

    assert_no_difference "User.count" do
      post google_signup_path, params: { user: { terms_accepted: "0" } }
    end

    assert_response :unprocessable_entity
    assert_nil User.find_by(email: "recusa@example.com")
  end

  test "POST sem o parametro user inteiro nao cria a conta nem quebra" do
    start_pending_google_signup(email: "sem-parametro@example.com", uid: "uid-sem-parametro")

    assert_no_difference "User.count" do
      post google_signup_path, params: {}
    end

    assert_response :unprocessable_entity
    assert_nil User.find_by(email: "sem-parametro@example.com")
  end

  test "depois de criar a conta o cadastro pendente sai da sessao" do
    start_pending_google_signup(email: "limpa-sessao@example.com", uid: "uid-limpa")
    post google_signup_path, params: { user: { terms_accepted: "1" } }

    get new_google_signup_path
    assert_redirected_to new_user_session_path
  end
end
