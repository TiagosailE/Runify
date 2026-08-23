class ActivitiesController < ApplicationController
  before_action :authenticate_user!

  rate_limit to: 20, within: 1.hour, only: [ :create, :import ], by: -> { current_user.id },
    with: -> { redirect_to history_path, alert: "Muitas atividades registradas em pouco tempo. Tente novamente mais tarde." }

  def new
    @activity = current_user.activities.new(start_date: Time.current)
  end

  def create
    duration = duration_from_params

    @activity = current_user.activities.new(activity_params)
    @activity.distance = params.dig(:activity, :distance_km).to_f * 1000
    @activity.duration = duration
    @activity.moving_time = duration
    @activity.average_speed = duration > 0 ? (@activity.distance / duration) : nil
    @activity.sport_type = "Run"
    @activity.source = "manual"
    @activity.name = @activity.name.presence || "Corrida"

    if @activity.save
      XpService.award_xp(current_user, @activity) if defined?(XpService)
      flash[:toast] = { message: "Atividade registrada!", type: "success" }
      redirect_to history_path
    else
      flash.now[:toast] = { message: @activity.errors.full_messages.first, type: "error" }
      render :new, status: :unprocessable_entity
    end
  end

  def new_import
  end

  def import
    file = params[:file]

    unless file.present?
      flash[:toast] = { message: "Selecione um arquivo GPX ou TCX", type: "error" }
      redirect_to new_activity_import_path and return
    end

    unless file.original_filename.match?(/\.(gpx|tcx)\z/i)
      flash[:toast] = { message: "Envie um arquivo .gpx ou .tcx", type: "error" }
      redirect_to new_activity_import_path and return
    end

    parsed = ActivityFileParser.new(file).parse
    activity = current_user.activities.new(parsed.merge(source: "import"))

    if activity.save
      XpService.award_xp(current_user, activity) if defined?(XpService)
      flash[:toast] = { message: "Atividade importada com sucesso!", type: "success" }
      redirect_to history_path
    else
      flash[:toast] = { message: activity.errors.full_messages.first, type: "error" }
      redirect_to new_activity_import_path
    end
  rescue ActivityFileParser::ParseError => e
    flash[:toast] = { message: e.message, type: "error" }
    redirect_to new_activity_import_path
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

  def duration_from_params
    hours = params.dig(:activity, :duration_hours).to_i
    minutes = params.dig(:activity, :duration_minutes).to_i
    seconds = params.dig(:activity, :duration_seconds).to_i
    (hours * 3600) + (minutes * 60) + seconds
  end
end
