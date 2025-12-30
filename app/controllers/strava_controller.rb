class StravaController < ApplicationController
  before_action :authenticate_user!

  def connect
    oauth_client = Strava::OAuth::Client.new(
      client_id: ENV['STRAVA_CLIENT_ID'],
      client_secret: ENV['STRAVA_CLIENT_SECRET']
    )

    redirect_url = oauth_client.authorize_url(
      redirect_uri: strava_callback_url,
      approval_prompt: 'force',
      response_type: 'code',
      scope: 'activity:read_all,profile:read_all',
      state: 'strava_connect'
    )

    redirect_to redirect_url, allow_other_host: true
  end

  def callback
    code = params[:code]

    oauth_client = Strava::OAuth::Client.new(
      client_id: ENV['STRAVA_CLIENT_ID'],
      client_secret: ENV['STRAVA_CLIENT_SECRET']
    )

    response = oauth_client.oauth_token(code: code)

    current_user.create_strava_integration!(
      strava_athlete_id: response.athlete.id.to_s,
      access_token: response.access_token,
      refresh_token: response.refresh_token,
      token_expires_at: Time.at(response.expires_at),
      athlete_data: response.athlete.to_h,
      active: true
    )

    sync_activities

    redirect_to dashboard_path, notice: 'Strava conectado com sucesso!'
  rescue => e
    redirect_to dashboard_path, alert: "Erro ao conectar com Strava: #{e.message}"
  end

  def disconnect
    current_user.strava_integration&.destroy
    redirect_to dashboard_path, notice: 'Strava desconectado com sucesso!'
  end

  private

  def sync_activities
    integration = current_user.strava_integration

    activities = integration.fetch_recent_activities(per_page: 10)

    activities.each do |strava_activity|
      current_user.activities.find_or_create_by(strava_activity_id: strava_activity.id.to_s) do |activity|
        activity.name = strava_activity.name
        activity.sport_type = strava_activity.sport_type
        activity.distance = strava_activity.distance
        activity.duration = strava_activity.elapsed_time
        activity.moving_time = strava_activity.moving_time
        activity.average_speed = strava_activity.average_speed
        activity.start_date = strava_activity.start_date
        activity.activity_data = strava_activity.to_h
      end
    end

    integration.update(last_sync_at: Time.current)
  end
end