class StravaController < ApplicationController
  before_action :authenticate_user!, except: [ :callback ]

  def connect
    state = SecureRandom.hex(16)
    session[:strava_oauth_state] = state
    session[:strava_connecting_user_id] = current_user.id

    oauth_client = Strava::OAuth::Client.new(
      client_id: ENV["STRAVA_CLIENT_ID"],
      client_secret: ENV["STRAVA_CLIENT_SECRET"]
    )

    redirect_url = oauth_client.authorize_url(
      redirect_uri: ENV.fetch("STRAVA_REDIRECT_URI", strava_callback_url),
      approval_prompt: "force",
      response_type: "code",
      scope: "activity:read_all,profile:read_all",
      state: state
    )

    redirect_to redirect_url, allow_other_host: true
  end

  def callback
    expected_state = session.delete(:strava_oauth_state)
    user_id = session.delete(:strava_connecting_user_id)
    user = User.find_by(id: user_id)

    unless user && params[:state].present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, expected_state.to_s)
      flash[:toast] = { message: "Sessão expirada. Tente conectar novamente.", type: "error" }
      redirect_to(user_signed_in? ? dashboard_path : new_user_session_path) and return
    end

    if params[:error].present?
      flash[:toast] = { message: "Conexão com o Strava cancelada.", type: "info" }
      redirect_to dashboard_path and return
    end

    unless params[:code].present?
      flash[:toast] = { message: "Código não recebido do Strava", type: "error" }
      redirect_to dashboard_path and return
    end

    oauth_client = Strava::OAuth::Client.new(
      client_id: ENV["STRAVA_CLIENT_ID"],
      client_secret: ENV["STRAVA_CLIENT_SECRET"]
    )

    token_response = oauth_client.oauth_token(code: params[:code])
    strava_athlete_id = token_response.athlete.id.to_s

    existing_integration = StravaIntegration.find_by(strava_athlete_id: strava_athlete_id)

    if existing_integration && existing_integration.user_id != user.id
      redirect_to dashboard_path, flash: {
        toast: { message: "Esta conta do Strava já está conectada a outro usuário do Runify.", type: "error" }
      } and return
    end

    user.strava_integration&.destroy

    user.create_strava_integration!(
      strava_athlete_id: strava_athlete_id,
      access_token: token_response.access_token,
      refresh_token: token_response.refresh_token,
      token_expires_at: Time.at(token_response.expires_at),
      athlete_data: token_response.athlete.to_h
    )

    sync_result = SyncStravaActivitiesJob.new.sync_user_activities(user)
    if sync_result[:error]
      Rails.logger.warn "Strava connected but first sync failed for user #{user.id}: #{sync_result[:error].message}"
    end

    flash[:toast] = { message: "Strava conectado com sucesso!", type: "success" }
    redirect_to dashboard_path

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Strava integration error: #{e.message}"
    flash[:toast] = { message: "Erro ao conectar: #{e.message}", type: "error" }
    redirect_to dashboard_path
  rescue Strava::Errors::Fault, Faraday::Error => e
    Rails.logger.error "Strava OAuth token exchange failed: #{e.message}"
    flash[:toast] = { message: "Erro ao conectar com Strava. Tente novamente.", type: "error" }
    redirect_to dashboard_path
  end

  def disconnect
    if current_user.strava_integration
      current_user.strava_integration.destroy
      flash[:toast] = { message: "Strava desconectado com sucesso!", type: "success" }
    else
      flash[:toast] = { message: "Nenhuma conta do Strava conectada.", type: "info" }
    end
    redirect_to dashboard_path
  end

  def sync
    integration = current_user.strava_integration

    unless integration
      flash[:toast] = { message: "Strava não conectado", type: "error" }
      redirect_to dashboard_path and return
    end

    result = SyncStravaActivitiesJob.new.sync_user_activities(
      current_user,
      limit: SyncStravaActivitiesJob::MANUAL_SYNC_LIMIT
    )

    if result[:error]
      # "Forbidden" sozinho nao diz nada para quem esta usando o app. Quando
      # a causa e a aplicacao desativada no Strava, nao ha nada que o usuario
      # possa fazer aqui -- o import de GPX resolve o mesmo problema, entao e
      # para la que ele deve ser mandado.
      flash[:toast] = if StravaIntegration.app_inactive_error?(result[:error])
        { message: "A integração com o Strava está indisponível no momento. Use " \
                   "\"Importar arquivo\" para trazer suas atividades (exporte o GPX " \
                   "pelo site do Strava).",
          type: "warning" }
      else
        { message: "Erro ao sincronizar: #{result[:error].message}", type: "error" }
      end
    else
      message = []
      message << "#{result[:new_count]} novas" if result[:new_count] > 0
      message << "#{result[:updated_count]} atualizadas" if result[:updated_count] > 0
      message << "Nenhuma nova atividade" if result[:new_count] == 0 && result[:updated_count] == 0

      flash[:toast] = { message: "Sincronizado! #{message.join(', ')}", type: "success" }
    end

    redirect_to dashboard_path
  end
end
