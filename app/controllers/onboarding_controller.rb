class OnboardingController < ApplicationController
  before_action :authenticate_user!

  def step1
  end

  def step2
    @weight = params[:weight]
    @height = params[:height]
    @birth_date = params[:birth_date]
    
    session[:onboarding_weight] = @weight
    session[:onboarding_height] = @height
    session[:onboarding_birth_date] = @birth_date
    
    redirect_to onboarding_step2_view_path
  end
  
  def step2_view
    @weight = session[:onboarding_weight]
    @height = session[:onboarding_height]
    @birth_date = session[:onboarding_birth_date]
  end

  def complete
    current_user.update(
      weight: session[:onboarding_weight],
      height: session[:onboarding_height],
      birth_date: session[:onboarding_birth_date],
      goal: params[:goal]
    )
    
    session.delete(:onboarding_weight)
    session.delete(:onboarding_height)
    session.delete(:onboarding_birth_date)
    
    redirect_to dashboard_path, notice: "Perfil completado com sucesso!"
  end
end