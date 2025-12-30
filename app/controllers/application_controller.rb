class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :weight, :height, :birth_date, :goal])
    devise_parameter_sanitizer.permit(:account_update, keys: [:username, :weight, :height, :birth_date, :goal])
  end

  def after_sign_in_path_for(resource)
    if resource.weight.nil? || resource.goal.nil?
      onboarding_step1_path
    else
      dashboard_path
    end
  end

  def after_sign_up_path_for(resource)
    onboarding_step1_path
  end
end