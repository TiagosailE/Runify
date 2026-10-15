class ActivitiesController < ApplicationController
  before_action :authenticate_user!

  rate_limit to: 20, within: 1.hour, only: [ :create ], by: -> { current_user.id },
    with: -> { redirect_to history_path, alert: "Muitas atividades registradas em pouco tempo. Tente novamente mais tarde." }

  def new
    @activity = current_user.activities.new(start_date: Time.current)
  end

  def create
    duration = duration_from_params

    @activity = current_user.activities.new(activity_params)
    @activity.sport_type = Activity::MANUAL_SPORT_TYPES.key?(params.dig(:activity, :sport_type)) ? params.dig(:activity, :sport_type) : "Run"
    @activity.treadmill = params.dig(:activity, :treadmill) == "1"
    @activity.incline_percent = @activity.treadmill? ? params.dig(:activity, :incline_percent).presence : nil
    @activity.distance = distance_km_from_params(duration, @activity.treadmill?) * 1000
    @activity.duration = duration
    @activity.moving_time = duration
    @activity.average_speed = duration > 0 ? (@activity.distance / duration) : nil
    @activity.source = "manual"
    @activity.name = @activity.name.presence || default_name(@activity)

    if @activity.save
      XpService.update_streak(current_user)
      XpService.award_xp(current_user, @activity)
      flash[:toast] = { message: "Atividade registrada!", type: "success" }
      redirect_to history_path
    else
      flash.now[:toast] = { message: @activity.errors.full_messages.first, type: "error" }
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    activity = current_user.activities.find(params[:id])
    activity.destroy
    flash[:toast] = { message: "Atividade removida", type: "success" }
    redirect_to history_path
  end

  private

  def activity_params
    params.require(:activity).permit(:name, :start_date)
  end

  # Esteira que só mostra a velocidade: distância = velocidade x tempo. A
  # distância do painel, quando informada, sempre prevalece.
  def distance_km_from_params(duration, treadmill)
    distance_km = params.dig(:activity, :distance_km).to_f
    speed_kmh = params.dig(:activity, :speed_kmh).to_f
    return distance_km if distance_km.positive? || !treadmill || !speed_kmh.positive?

    (speed_kmh * duration / 3600.0).round(2)
  end

  def default_name(activity)
    name = Activity::MANUAL_SPORT_TYPES.fetch(activity.sport_type)
    activity.treadmill? ? "#{name} na esteira" : name
  end

  def duration_from_params
    hours = params.dig(:activity, :duration_hours).to_i
    minutes = params.dig(:activity, :duration_minutes).to_i
    seconds = params.dig(:activity, :duration_seconds).to_i
    (hours * 3600) + (minutes * 60) + seconds
  end
end
