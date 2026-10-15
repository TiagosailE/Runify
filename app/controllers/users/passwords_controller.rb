# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  SENT_MESSAGE = "Se o e-mail estiver cadastrado, você receberá um código de 6 dígitos em alguns minutos."
  RATE_LIMITED = -> { redirect_to new_user_password_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  skip_before_action :assert_reset_token_passed

  rate_limit to: 5, within: 15.minutes, only: :create, with: RATE_LIMITED
  # Por e-mail tambem: trocar de IP nao gera codigo novo sem limite para a
  # mesma conta.
  rate_limit to: 5, within: 1.hour, only: :create, name: "por_email", with: RATE_LIMITED,
    by: -> { params.dig(:user, :email).to_s.strip.downcase }
  rate_limit to: 10, within: 15.minutes, only: :update, with: RATE_LIMITED

  # A resposta e a mesma exista a conta ou nao: sempre segue para a tela do
  # codigo. Conta criada pelo Google nao tem senha do Runify para redefinir:
  # recebe so a orientacao de entrar pelo Google.
  def create
    self.resource = resource_class.new(email: submitted_email)
    return render_with_errors(:new) unless valid_email?

    deliver_recovery_instructions(resource_class.find_by(email: resource.email))
    session[:password_reset_email] = resource.email
    flash[:toast] = { message: SENT_MESSAGE, type: "success" }
    redirect_to edit_user_password_path
  end

  def edit
    self.resource = resource_class.new(email: session[:password_reset_email])
    set_minimum_password_length
  end

  def update
    self.resource = resource_class.new(email: submitted_email)
    set_minimum_password_length
    return render_with_errors(:edit) unless valid_email?

    code = params.dig(:user, :reset_code).to_s.gsub(/\D/, "")
    if code.blank?
      resource.errors.add(:reset_code, :blank)
      return render_with_errors(:edit)
    end

    user = resource_class.find_by(email: resource.email)
    if user.nil?
      resource.errors.add(:reset_code, :invalid)
      return render_with_errors(:edit)
    end

    self.resource = user
    unless user.reset_password_with_code(code, params.dig(:user, :password), params.dig(:user, :password_confirmation))
      return render_with_errors(:edit)
    end

    session.delete(:password_reset_email)
    set_flash_message!(:notice, :updated)
    sign_in(resource_name, user)
    redirect_to after_resetting_password_path_for(user)
  end

  private

  def submitted_email
    params.dig(:user, :email).to_s.strip.downcase
  end

  def valid_email?
    if resource.email.blank?
      resource.errors.add(:email, :blank)
    elsif !Devise.email_regexp.match?(resource.email)
      resource.errors.add(:email, :invalid)
    end
    resource.errors.empty?
  end

  def render_with_errors(view)
    flash.now[:toast] = { message: resource.errors.full_messages.first, type: "error" }
    render view, status: :unprocessable_entity
  end

  # Em producao a entrega levanta erro (raise_delivery_errors). Mostrar isso
  # revelaria que a conta existe, entao o erro vai para o log e o Sentry.
  def deliver_recovery_instructions(user)
    return if user.nil?

    if user.provider.present?
      UserMailer.google_account_recovery(user).deliver_now
    else
      user.send_password_reset_code
    end
  rescue StandardError => e
    Rails.error.report(e, handled: true)
    Rails.logger.error "Falha ao enviar recuperacao de senha para o usuario #{user.id}: #{e.class} - #{e.message}"
  end
end
