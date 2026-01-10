class StravaController < ApplicationController
  before_action :authenticate_user!

  def connect
    puts ">>> CONNECT: user_id = #{current_user.id}"
    
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
    
    puts ">>> CALLBACK URL: #{strava_callback_url}"

    redirect_to redirect_url, allow_other_host: true
  end

  def callback
    puts ">>> CALLBACK CHAMADO!"
    puts ">>> Params: #{params.inspect}"
    puts ">>> current_user: #{current_user.inspect}"
    
    code = params[:code]
    
    unless code
      puts ">>> ERRO: Sem código!"
      flash[:toast] = { message: 'Código não recebido', type: 'error' }
      redirect_to dashboard_path
      return
    end

    oauth_client = Strava::OAuth::Client.new(
      client_id: ENV['STRAVA_CLIENT_ID'],
      client_secret: ENV['STRAVA_CLIENT_SECRET']
    )

    response = oauth_client.oauth_token(code: code)
    
    puts ">>> Token recebido! Athlete: #{response.athlete.id}"

    existing_integration = StravaIntegration.find_by(strava_athlete_id: response.athlete.id.to_s)
    
    if existing_integration && existing_integration.user_id != current_user.id
      flash[:toast] = { message: 'Esta conta do Strava já está conectada a outro usuário do Runify.', type: 'error' }
      redirect_to dashboard_path
      return
    end

    if current_user.strava_integration
      current_user.strava_integration.destroy
    end

    current_user.create_strava_integration!(
      strava_athlete_id: response.athlete.id.to_s,
      access_token: response.access_token,
      refresh_token: response.refresh_token,
      token_expires_at: Time.at(response.expires_at),
      athlete_data: response.athlete.to_h,
      active: true
    )
    
    puts ">>> Integração criada!"

    sync_activities
    
    puts ">>> Sincronização concluída!"

    flash[:toast] = { message: 'Strava conectado com sucesso!', type: 'success' }
    redirect_to dashboard_path
  rescue ActiveRecord::RecordInvalid => e
    puts ">>> ERRO: #{e.message}"
    flash[:toast] = { message: "Erro ao conectar: #{e.message}", type: 'error' }
    redirect_to dashboard_path
  rescue => e
    puts ">>> ERRO GERAL: #{e.message}"
    puts e.backtrace.first(5).join("\n")
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
      redirect_to dashboard_path
      return
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
      Rails.logger.error e.backtrace.join("\n")
      flash[:toast] = { message: "Erro ao sincronizar: #{e.message}", type: 'error' }
      redirect_to dashboard_path
    end
  end

  private

  def sync_activities
    integration = current_user.strava_integration
    client = integration.strava_client

    activities = client.athlete_activities(per_page: 10)

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