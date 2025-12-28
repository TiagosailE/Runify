class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :weight, :height, :birth_date, :goal])
    devise_parameter_sanitizer.permit(:account_update, keys: [:username, :weight, :height, :birth_date, :goal])
  end
end