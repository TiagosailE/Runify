# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  rate_limit to: 5, within: 1.hour, only: :create,
    with: -> { redirect_to new_user_registration_path, alert: "Muitas tentativas de cadastro. Tente novamente mais tarde." }
end
