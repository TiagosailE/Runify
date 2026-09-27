class TrainingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workout, only: [ :show, :complete, :feedback ]

  def index
    @training_plan = current_user.active_training_plan

    if @training_plan
      @current_week = @training_plan.current_week
      @week_workouts = @training_plan.workouts_for_week(@current_week)
      @today_workout = @week_workouts.find { |w| w.scheduled_date == Date.current }
      @week_progress = calculate_week_progress(@week_workouts)
    else
      render "no_plan"
    end
  end

  def generate
    AiTrainingService.new(current_user).generate_training_plan
    flash[:toast] = { message: "Plano de treino gerado com sucesso!", type: "success" }
    redirect_to training_index_path
  rescue => e
    flash[:toast] = { message: "Erro ao gerar plano: #{e.message}", type: "error" }
    redirect_to training_index_path
  end

  def show
  end

  def complete
    if @workout.mark_as_completed!
      NotificationService.send_congratulations(current_user, @workout)

      render json: { success: true, message: "Treino concluído!" }
    else
      render json: { success: false, message: "Erro ao completar treino" }, status: :unprocessable_entity
    end
  end

  def feedback
    @workout.update(
      workout_details: (@workout.workout_details || {}).merge({
        "user_feedback" => {
          "difficulty" => feedback_params[:difficulty],
          "notes" => feedback_params[:notes],
          "completed_at" => Time.current
        }
      })
    )

    render json: { success: true, message: "Feedback enviado!" }
  end

  private

  def set_workout
    @workout = Workout.joins(:training_plan).find_by!(id: params[:id], training_plans: { user_id: current_user.id })
  end

  def feedback_params
    params.permit(:difficulty, :notes)
  end

  def calculate_week_progress(workouts)
    return 0 if workouts.empty?
    completed = workouts.count { |w| w.completed? }
    ((completed.to_f / workouts.count) * 100).round
  end
end
