class StravaController < ApplicationController
  before_action :authenticate_user!, except: [:callback]

  def connect
    session[:strava_connecting_user_id] = current_user.id

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
    user_id = session.delete(:strava_connecting_user_id)
    user = User.find_by(id: user_id) || current_user

    unless user
      flash[:toast] = { message: 'Sessão expirada. Faça login novamente.', type: 'error' }
      redirect_to new_user_session_path and return
    end

    unless code
      flash[:toast] = { message: 'Código não recebido do Strava', type: 'error' }
      redirect_to dashboard_path and return
    end

    unless params[:state] == 'strava_connect'
      flash[:toast] = { message: 'Requisição inválida', type: 'error' }
      redirect_to dashboard_path and return
    end

    oauth_client = Strava::OAuth::Client.new(
      client_id: ENV['STRAVA_CLIENT_ID'],
      client_secret: ENV['STRAVA_CLIENT_SECRET']
    )

    token_response = oauth_client.oauth_token(code: code)

    existing_integration = StravaIntegration.find_by(strava_athlete_id: token_response.athlete.id.to_s)

    if existing_integration && existing_integration.user_id != user.id
      flash[:toast] = { message: 'Esta conta do Strava já está conectada a outro usuário do Runify.', type: 'error' }
      redirect_to dashboard_path and return
    end

    user.strava_integration&.destroy

    user.create_strava_integration!(
      strava_athlete_id: token_response.athlete.id.to_s,
      access_token: token_response.access_token,
      refresh_token: token_response.refresh_token,
      token_expires_at: Time.at(token_response.expires_at),
      athlete_data: token_response.athlete.to_h,
      active: true
    )

    sync_activities(user)

    flash[:toast] = { message: 'Strava conectado com sucesso!', type: 'success' }
    redirect_to dashboard_path
  rescue ActiveRecord::RecordInvalid => e
    flash[:toast] = { message: "Erro ao conectar: #{e.message}", type: 'error' }
    redirect_to dashboard_path
  rescue => e
    Rails.logger.error "Strava callback error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    flash[:toast] = { message: "Erro ao conectar com Strava: #{e.message}", type: 'error' }
    redirect_to dashboard_path
  end

  def disconnect
    current_user.strava_integration&.destroy
    flash[:toast] = { message: 'Strava desconectado com sucesso!', type: 'success' }
    redirect_to dashboard_path
  end

  def sync
    integration = current_user.strava_integration

    unless integration
      flash[:toast] = { message: 'Strava não conectado', type: 'error' }
      redirect_to dashboard_path and return
    end

    begin
      activities = integration.fetch_recent_activities(per_page: 30)
      new_count = 0
      updated_count = 0

      activities.each do |strava_activity|
        activity = current_user.activities.find_or_initialize_by(strava_activity_id: strava_activity.id.to_s)
        is_new = activity.new_record?

        activity.assign_attributes(
          name: strava_activity.name,
          sport_type: strava_activity.sport_type,
          distance: strava_activity.distance,
          duration: strava_activity.elapsed_time,
          moving_time: strava_activity.moving_time,
          average_speed: strava_activity.average_speed,
          start_date: strava_activity.start_date,
          activity_data: strava_activity.to_h
        )

        if activity.save
          if is_new
            XpService.award_xp(current_user, activity)
            new_count += 1
          else
            updated_count += 1
          end
        end
      end

      integration.update(last_sync_at: Time.current)

      message = []
      message << "#{new_count} novas" if new_count > 0
      message << "#{updated_count} atualizadas" if updated_count > 0
      message << "Nenhuma nova" if new_count == 0 && updated_count == 0

      flash[:toast] = { message: "Sincronizado! #{message.join(', ')}", type: 'success' }
      redirect_to dashboard_path
    rescue => e
      Rails.logger.error "Sync error: #{e.message}"
      flash[:toast] = { message: "Erro ao sincronizar: #{e.message}", type: 'error' }
      redirect_to dashboard_path
    end
  end

  private

  def sync_activities(user)
    integration = user.strava_integration
    client = integration.strava_client
    activities = client.athlete_activities(per_page: 10)

    activities.each do |strava_activity|
      user.activities.find_or_create_by(strava_activity_id: strava_activity.id.to_s) do |activity|
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