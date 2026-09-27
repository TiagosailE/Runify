require "test_helper"
require "ostruct"

class StravaIntegrationTest < ActiveSupport::TestCase
  test "refresh_token! updates token fields" do
    user = users(:one)
    user.strava_integration.destroy
    integration = StravaIntegration.create!(user: user, access_token: "old", refresh_token: "rtok", token_expires_at: 1.minute.ago, active: true)

    fake_oauth = Object.new
    def fake_oauth.oauth_token(_opts = {})
      OpenStruct.new(access_token: "new_access", refresh_token: "new_refresh", expires_at: (Time.current + 1.day).to_i)
    end

    Strava::OAuth::Client.stub :new, fake_oauth do
      integration.refresh_token!
    end

    integration.reload
    assert_equal "new_access", integration.access_token
    assert_equal "new_refresh", integration.refresh_token
    assert integration.token_expires_at > Time.current
  end

  test "fetch_recent_activities uses Strava::Api::Client" do
    user = users(:one)
    user.strava_integration.destroy
    integration = StravaIntegration.create!(user: user, access_token: "token", refresh_token: "rtok", token_expires_at: Time.current + 1.day, active: true)

    fake_api = Object.new
    def fake_api.athlete_activities(_opts = {})
      [ OpenStruct.new(id: 123, name: "Run") ]
    end

    Strava::Api::Client.stub :new, fake_api do
      activities = integration.fetch_recent_activities(per_page: 5)
      assert_equal 1, activities.length
      assert_equal 123, activities.first.id
    end
  end

  # Erro real capturado da API em 2026-08-23: o OAuth continua funcionando
  # (o refresh de token passa) e mesmo assim TODO endpoint de dados devolve
  # 403 com este corpo, porque a aplicacao esta desativada no Strava. Sem
  # olhar este campo o erro chega como um "Forbidden" indiagnosticavel.
  class FakeFault < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super("Forbidden")
    end
  end

  test "reconhece o erro de aplicação desativada" do
    error = FakeFault.new([ { "resource" => "Application", "field" => "Status", "code" => "Inactive" } ])

    assert StravaIntegration.app_inactive_error?(error)
  end

  test "não confunde outro 403 com aplicação desativada" do
    error = FakeFault.new([ { "resource" => "Athlete", "field" => "access_token", "code" => "invalid" } ])

    assert_not StravaIntegration.app_inactive_error?(error)
  end

  test "erro sem detalhes não quebra a classificação" do
    assert_not StravaIntegration.app_inactive_error?(StandardError.new("boom"))
    assert_not StravaIntegration.app_inactive_error?(FakeFault.new(nil))
  end

  test "access_token cifrado no esquema deterministico antigo continua legivel" do
    integration = strava_integrations(:one)

    old_key_provider = ActiveRecord::Encryption::Scheme.new(deterministic: true).key_provider
    old_ciphertext = ActiveRecord::Encryption::Encryptor.new.encrypt("token-antigo", key_provider: old_key_provider)

    StravaIntegration.connection.execute(
      "UPDATE strava_integrations SET access_token = #{StravaIntegration.connection.quote(old_ciphertext)} WHERE id = #{integration.id}"
    )

    assert_equal "token-antigo", integration.reload.access_token
  end

  test "segunda integracao para o mesmo usuario falha no banco" do
    user = users(:one)

    assert_raises(ActiveRecord::RecordNotUnique) do
      StravaIntegration.create!(
        user: user, strava_athlete_id: "9999999", access_token: "a", refresh_token: "r",
        token_expires_at: 1.day.from_now, active: true
      )
    end
  end

  test "access_token gravado de novo deixa de ser deterministico" do
    a = strava_integrations(:one)
    b = strava_integrations(:two)

    a.update!(access_token: "mesmo-valor")
    b.update!(access_token: "mesmo-valor")

    raw_a = StravaIntegration.connection.select_value("SELECT access_token FROM strava_integrations WHERE id = #{a.id}")
    raw_b = StravaIntegration.connection.select_value("SELECT access_token FROM strava_integrations WHERE id = #{b.id}")

    assert_not_equal raw_a, raw_b
  end
end
