class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :confine_admin_to_panel

  ADMIN_ALLOWED_CONTROLLERS = %w[pages].freeze

  protected

  # Conta de administrador nao navega o app como corredor -- so acessa /admin,
  # o Devise (para sair) e as paginas publicas.
  def confine_admin_to_panel
    return unless user_signed_in? && current_user.admin?
    return if devise_controller?
    return if controller_path.start_with?("admin/")
    return if ADMIN_ALLOWED_CONTROLLERS.include?(controller_path)

    redirect_to admin_root_path, alert: "Esta conta é exclusiva do painel administrativo."
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username, :weight, :height, :birth_date, :goal, :terms_accepted ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username, :weight, :height, :birth_date, :goal, :avatar ])
  end

  def after_sign_in_path_for(resource)
    # Antes das checagens de onboarding: conta de admin nao tem peso/objetivo
    # preenchidos e ficaria presa no passo 1 sem essa ordem.
    return admin_root_path if resource.admin?

    if resource.weight.nil?
      onboarding_step1_path
    elsif resource.goal.nil?
      onboarding_step2_view_path
    else
      dashboard_path
    end
  end

  def after_sign_up_path_for(resource)
    onboarding_step1_path
  end
end
