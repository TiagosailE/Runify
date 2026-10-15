# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_user_session_path, alert: "Muitas tentativas de login. Tente novamente em alguns minutos." }

  # Campo vazio ou e-mail mal formatado nem chega ao Devise: volta com o erro
  # no campo. Conta inexistente e senha errada saem pelas mensagens do
  # devise.pt-BR.yml (failure.not_found_in_database / failure.invalid).
  def create
    email = params.dig(:user, :email).to_s.strip
    self.resource = resource_class.new(email: email)

    if email.blank?
      resource.errors.add(:email, :blank)
    elsif !Devise.email_regexp.match?(email)
      resource.errors.add(:email, :invalid)
    end
    resource.errors.add(:password, :blank) if params.dig(:user, :password).blank?

    return super if resource.errors.empty?

    flash.now[:toast] = { message: resource.errors.full_messages.first, type: "error" }
    render :new, status: :unprocessable_entity
  end
end
