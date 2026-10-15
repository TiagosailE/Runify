# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  rate_limit to: 5, within: 1.hour, only: :create,
    with: -> { redirect_to new_user_registration_path, alert: "Muitas tentativas de cadastro. Tente novamente mais tarde." }

  def create
    super do |user|
      unless user.persisted?
        flash.now[:toast] = { message: "Não foi possível criar a conta. Confira os campos destacados.", type: "error" }
      end
    end
  end
end
