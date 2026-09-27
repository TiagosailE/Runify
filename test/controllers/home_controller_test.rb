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

  test "pedal nao soma km no ranking semanal do squad" do
    user = users(:one)
    user.activities.create!(
      name: "Pedal", sport_type: "Ride", distance: 20_000, duration: 3600,
      moving_time: 3600, start_date: Time.current, source: "manual"
    )

    get dashboard_url

    assert_response :success
    assert_match "0.0 km", response.body
    assert_no_match "20.0 km", response.body
  end
end
