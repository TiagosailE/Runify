# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  rate_limit to: 5, within: 15.minutes, only: :create,
    with: -> { redirect_to new_user_password_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }
end
