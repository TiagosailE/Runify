class StravaIntegration < ApplicationRecord
  belongs_to :user

  # Buffer before expiry to proactively refresh the token
  REFRESH_BUFFER = 1.minute

  def token_expired?
    token_expires_at.present? && token_expires_at < Time.current
  end

  def token_needs_refresh?(buffer: REFRESH_BUFFER)
    token_expires_at.present? && token_expires_at < Time.current + buffer
  end

  # Ensure token is valid (refresh if about to expire)
  def ensure_valid_token!
    refresh_token! if token_needs_refresh?
  end

  # Returns a Strava API client with a valid (refreshed when necessary) token
  def strava_client
    ensure_valid_token!
    Strava::Api::Client.new(access_token: access_token)
  end

  # Refresh the access token using the stored refresh_token
  def refresh_token!
    return unless refresh_token.present?

    oauth_client = Strava::OAuth::Client.new(
      client_id: ENV['STRAVA_CLIENT_ID'],
      client_secret: ENV['STRAVA_CLIENT_SECRET']
    )

    response = oauth_client.oauth_token(
      refresh_token: refresh_token,
      grant_type: 'refresh_token'
    )

    update!(
      access_token: response.access_token,
      refresh_token: response.refresh_token,
      token_expires_at: Time.at(response.expires_at)
    )
  rescue => e
    Rails.logger.error("Strava token refresh failed for user_id=#{user_id}: #{e.message}")
    raise
  end

  # Convenience method to fetch activities from Strava (automatically ensures token validity)
  def fetch_recent_activities(per_page: 30)
    client = strava_client
    client.athlete_activities(per_page: per_page)
  end
end