class OnboardingController < ApplicationController
  before_action :authenticate_user!

  def step1
  end

  def step2
    @weight = params[:weight]
    @height = params[:height]
    @birth_date = params[:birth_date]
    @available_days = params[:available_days] || []
    
    session[:onboarding_weight] = @weight
    session[:onboarding_height] = @height
    session[:onboarding_birth_date] = @birth_date
    session[:onboarding_available_days] = @available_days.to_json
    
    redirect_to onboarding_step2_view_path
  end
  
  def step2_view
    @weight = session[:onboarding_weight]
    @height = session[:onboarding_height]
    @birth_date = session[:onboarding_birth_date]
  end

  def complete
    available_days = JSON.parse(session[:onboarding_available_days] || '[]')
    
    best_5k = params[:best_5k_time].present? ? (params[:best_5k_time].to_f * 60).to_i : nil
    best_10k = params[:best_10k_time].present? ? (params[:best_10k_time].to_f * 60).to_i : nil
    best_half = params[:best_half_marathon_time].present? ? (params[:best_half_marathon_time].to_f * 60).to_i : nil
    
    preferred_days = params[:preferred_training_days].present? ? params[:preferred_training_days].reject(&:blank?).map(&:to_i) : []
    
    current_user.update(
      weight: session[:onboarding_weight],
      height: session[:onboarding_height],
      birth_date: session[:onboarding_birth_date],
      available_days: available_days,
      goal: params[:goal],
      running_experience: params[:running_experience],
      running_experience_years: params[:running_experience_years],
      best_5k_time: best_5k,
      best_10k_time: best_10k,
      best_half_marathon_time: best_half,
      weekly_mileage: params[:weekly_mileage],
      injury_history: params[:injury_history],
      preferred_training_days: preferred_days
    )
    
    session.delete(:onboarding_weight)
    session.delete(:onboarding_height)
    session.delete(:onboarding_birth_date)
    session.delete(:onboarding_available_days)
    
    redirect_to dashboard_path, notice: "Perfil completado com sucesso!"
  end
end