class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username, :weight, :height, :birth_date, :goal, :available_days, :terms_accepted ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username, :weight, :height, :birth_date, :goal, :available_days, :avatar ])
  end

  def after_sign_in_path_for(resource)
    # Administrador cai direto no painel: entrar com a conta de admin ja e
    # entrar no modo admin. Vem antes das checagens de onboarding de proposito
    # -- uma conta de suporte nao precisa ter peso e objetivo preenchidos, e
    # sem isso ela ficaria presa no passo 1 sem nunca chegar ao painel.
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
