# frozen_string_literal: true

class Users::GoogleSignupsController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :create,
    with: -> { redirect_to new_user_session_path, alert: "Muitas tentativas de cadastro. Tente novamente mais tarde." }

  before_action :require_pending_google_signup

  def new
  end

  def create
    password = Devise.friendly_token[0, 20]

    user = User.new(
      email: @pending_signup[:email],
      username: @pending_signup[:name],
      provider: "google_oauth2",
      uid: @pending_signup[:uid],
      password: password,
      password_confirmation: password,
      terms_accepted: params.dig(:user, :terms_accepted)
    )

    if user.save
      session.delete(:google_pending_signup)
      sign_in(user)
      flash[:toast] = { message: "Conta criada com sucesso!", type: "success" }
      redirect_to after_sign_in_path_for(user)
    else
      @user = user
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_pending_google_signup
    @pending_signup = session[:google_pending_signup]&.symbolize_keys
    redirect_to new_user_session_path, alert: "Sessão expirada. Tente entrar com o Google novamente." unless @pending_signup
  end
end
