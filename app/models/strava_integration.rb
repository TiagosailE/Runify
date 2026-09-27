class StravaIntegration < ApplicationRecord
  belongs_to :user

  encrypts :access_token, previous: { deterministic: true }
  encrypts :refresh_token

  validates :strava_athlete_id, uniqueness: {
  message: "já está conectado a outra conta do Runify"
}

  REFRESH_BUFFER = 1.minute

  # 403 com este codigo = a APLICACAO (nao o token) esta desativada do lado
  # do Strava. O OAuth (refresh de token) continua funcionando normalmente,
  # o que torna o erro dificil de diagnosticar sem olhar este campo.
  APP_INACTIVE_CODE = "Inactive"

  def self.app_inactive_error?(error)
    return false unless error.respond_to?(:errors)

    Array(error.errors).any? do |detail|
      detail.is_a?(Hash) && detail["resource"] == "Application" && detail["code"] == APP_INACTIVE_CODE
    end
  rescue StandardError
    false
  end

  def token_expired?
    token_expires_at.present? && token_expires_at < Time.current
  end

  def token_needs_refresh?(buffer: REFRESH_BUFFER)
    token_expires_at.present? && token_expires_at < Time.current + buffer
  end

  def ensure_valid_token!
    refresh_token! if token_needs_refresh?
  end

  def strava_client
    ensure_valid_token!
    Strava::Api::Client.new(access_token: access_token)
  end

  def refresh_token!
  return unless refresh_token.present?

  oauth_client = Strava::OAuth::Client.new(
    client_id: ENV["STRAVA_CLIENT_ID"],
    client_secret: ENV["STRAVA_CLIENT_SECRET"]
  )

  token_response = oauth_client.oauth_token(
    refresh_token: refresh_token,
    grant_type: "refresh_token"
  )

  update!(
    access_token: token_response.access_token,
    refresh_token: token_response.refresh_token,
    token_expires_at: Time.at(token_response.expires_at)
  )
rescue => e
  Rails.logger.error("Strava token refresh failed for user_id=#{user_id}: #{e.message}")
  raise
end

  def fetch_recent_activities(per_page: 30)
    client = strava_client
    client.athlete_activities(per_page: per_page)
  end
end
