class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :confine_admin_to_panel

  # Paginas publicas (privacidade, termos, sobre) continuam abertas para o
  # administrador -- sao documentos, nao funcionalidade de corredor.
  ADMIN_ALLOWED_CONTROLLERS = %w[pages].freeze

  protected

  # Conta de administrador e exclusiva do painel: nao navega o app como
  # corredor. Sem isso, a seta de "voltar" e qualquer URL digitada colocavam a
  # conta de suporte dentro do dashboard, do onboarding e dos Pacers.
  # Controllers do Devise ficam de fora ou o admin nao conseguiria sair.
  def confine_admin_to_panel
    return unless user_signed_in? && current_user.admin?
    return if devise_controller?
    return if controller_path.start_with?("admin/")
    return if ADMIN_ALLOWED_CONTROLLERS.include?(controller_path)

    redirect_to admin_root_path, alert: "Esta conta é exclusiva do painel administrativo."
  end

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
