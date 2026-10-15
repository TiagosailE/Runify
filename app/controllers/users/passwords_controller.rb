# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  SENT_MESSAGE = "Se o e-mail estiver cadastrado, você receberá as instruções em alguns minutos."

  rate_limit to: 5, within: 15.minutes, only: :create,
    with: -> { redirect_to new_user_password_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  # A resposta e a mesma exista a conta ou nao. Conta criada pelo Google nao
  # tem senha do Runify para redefinir: recebe so a orientacao de entrar pelo
  # Google.
  def create
    email = params.dig(:user, :email).to_s.strip.downcase
    self.resource = resource_class.new(email: email)

    if email.blank?
      resource.errors.add(:email, :blank)
    elsif !Devise.email_regexp.match?(email)
      resource.errors.add(:email, :invalid)
    end

    if resource.errors.any?
      flash.now[:toast] = { message: resource.errors.full_messages.first, type: "error" }
      return render :new, status: :unprocessable_entity
    end

    deliver_recovery_instructions(resource_class.find_by(email: email))
    flash[:toast] = { message: SENT_MESSAGE, type: "success" }
    redirect_to new_user_session_path
  end

  def update
    super do |user|
      flash.now[:toast] = { message: user.errors.full_messages.first, type: "error" } if user.errors.any?
    end
  end

  private

  # Em producao a entrega levanta erro (raise_delivery_errors). Mostrar isso
  # revelaria que a conta existe, entao o erro vai para o log e o Sentry.
  def deliver_recovery_instructions(user)
    return if user.nil?

    if user.provider.present?
      UserMailer.google_account_recovery(user).deliver_now
    else
      user.send_reset_password_instructions
    end
  rescue StandardError => e
    Rails.error.report(e, handled: true)
    Rails.logger.error "Falha ao enviar recuperacao de senha para o usuario #{user.id}: #{e.class} - #{e.message}"
  end
end
