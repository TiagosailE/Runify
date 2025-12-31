class TrainingController < ApplicationController
  before_action :authenticate_user!

  def index
    @training_plan = current_user.active_training_plan

    if @training_plan

      @current_week = @training_plan.current_week

      @week_workouts = @training_plan.workouts_for_week(@current_week)

      @today_workout = @week_workouts.find { |w| w.scheduled_date == Date.today }

      @week_progress = calculate_week_progress(@week_workouts)

    else

      render 'no_plan'
    end

  end

  def generate
    AiTrainingService.new(current_user).generate_training_plan

    redirect_to training_index_path, notice: 'Plano de treino gerado com sucesso!'

  rescue => e
    Rails.logger.error "Erro ao gerar plano: #{e.class} - #{e.message}\n#{e.backtrace.join("\n") }"
    redirect_to training_index_path, alert: "Erro ao gerar plano: #{e.message}"
  end

  def show
    @workout = Workout.find(params[:id])
  end

  def complete
    @workout = Workout.find(params[:id])
    @workout.mark_as_completed!
    render json: { success: true, message: 'Treino concluído!' }

  end

  def feedback
    @workout = Workout.find(params[:id])

    difficulty = params[:difficulty]

    notes = params[:notes]
    @workout.update(
      workout_details: @workout.workout_details.merge({
        'user_feedback' => {
          'difficulty' => difficulty,
          'notes' => notes,
          'completed_at' => Time.current
        }
      })
    )
    render json: { success: true, message: 'Feedback enviado!' }

  end
  private
  def calculate_week_progress(workouts)

    return 0 if workouts.empty?

    completed = workouts.count { |w| w.completed? }

    ((completed.to_f / workouts.count) * 100).round

  end

end