require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get dashboard_url
    assert_response :success
  end

  # Regressao: conectar o Strava e continuar sem atividade (a leitura falha do
  # lado deles) deixava o estado vazio oferecendo "Conectar com Strava" de
  # novo, como se a conexao nao tivesse funcionado.
  test "estado vazio com Strava conectado oferece sincronizar, nao conectar" do
    user = users(:one)
    user.activities.destroy_all
    user.strava_integration.update!(active: true)

    get dashboard_url

    assert_response :success
    assert_match "Sincronizar com Strava", response.body
    assert_no_match "Conectar com Strava", response.body
  end

  test "estado vazio sem Strava conectado oferece conectar" do
    user = users(:one)
    user.activities.destroy_all
    user.strava_integration.destroy!

    get dashboard_url

    assert_response :success
    assert_match "Conectar com Strava", response.body
    assert_no_match "Sincronizar com Strava", response.body
  end
end
