class OnboardingController < ApplicationController
  before_action :authenticate_user!

  def step1
  end

  # O peso e o que marca o passo 1 como feito (after_sign_in_path_for), entao
  # ele e obrigatorio aqui mesmo sendo opcional no modelo.
  def step2
    current_user.assign_attributes(
      weight: onboarding_step_params[:weight],
      height: onboarding_step_params[:height],
      birth_date: onboarding_step_params[:birth_date]
    )

    if current_user.weight.present? && current_user.save
      redirect_to onboarding_step2_view_path
    else
      current_user.validate
      current_user.errors.add(:weight, :blank) if current_user.weight.blank?
      flash.now[:toast] = { message: "Confira os campos destacados.", type: "error" }
      render :step1, status: :unprocessable_entity
    end
  end

  def step2_view
  end

  def complete
    best_5k = onboarding_complete_params[:best_5k_time].present? ? (onboarding_complete_params[:best_5k_time].to_f * 60).to_i : nil
    best_10k = onboarding_complete_params[:best_10k_time].present? ? (onboarding_complete_params[:best_10k_time].to_f * 60).to_i : nil
    best_half = onboarding_complete_params[:best_half_marathon_time].present? ? (onboarding_complete_params[:best_half_marathon_time].to_f * 60).to_i : nil
    preferred_days = onboarding_complete_params[:preferred_training_days].present? ? onboarding_complete_params[:preferred_training_days].reject(&:blank?).map(&:to_i) : []

    saved = current_user.update(
      goal: onboarding_complete_params[:goal],
      running_experience: onboarding_complete_params[:running_experience],
      running_experience_years: onboarding_complete_params[:running_experience_years],
      best_5k_time: best_5k,
      best_10k_time: best_10k,
      best_half_marathon_time: best_half,
      weekly_mileage: onboarding_complete_params[:weekly_mileage],
      injury_history: onboarding_complete_params[:injury_history],
      preferred_training_days: preferred_days
    )

    unless saved
      flash[:toast] = { message: current_user.errors.full_messages.first, type: "error" }
      return redirect_to onboarding_step2_view_path
    end

    redirect_to dashboard_path, notice: "Perfil completado com sucesso!"
  end

  private

  def onboarding_step_params
    params.permit(:weight, :height, :birth_date)
  end

  def onboarding_complete_params
    params.permit(
      :goal,
      :running_experience,
      :running_experience_years,
      :best_5k_time,
      :best_10k_time,
      :best_half_marathon_time,
      :weekly_mileage,
      :injury_history,
      preferred_training_days: []
    )
  end
end
