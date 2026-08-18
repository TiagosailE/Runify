class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @dark_mode = cookies[:dark_mode] == "true"
    @notifications_enabled = current_user.notifications_enabled
  end

  def update_password
    if current_user.valid_password?(password_params[:current_password])
      if password_params[:new_password] == password_params[:password_confirmation]
        if current_user.update(password: password_params[:new_password], password_confirmation: password_params[:password_confirmation])
          bypass_sign_in(current_user)
          flash[:toast] = { message: "Senha alterada com sucesso!", type: "success" }
          redirect_to settings_path
        else
          flash[:toast] = { message: current_user.errors.full_messages.join(", "), type: "error" }
          redirect_to settings_path
        end
      else
        flash[:toast] = { message: "As senhas não coincidem.", type: "error" }
        redirect_to settings_path
      end
    else
      flash[:toast] = { message: "Senha atual incorreta.", type: "error" }
      redirect_to settings_path
    end
  end

  def toggle_theme
    dark_mode = theme_params[:dark_mode] == true || theme_params[:dark_mode] == "true"
    cookies.permanent[:dark_mode] = dark_mode
    render json: { success: true, dark_mode: dark_mode }
  end

  def toggle_notifications
    enabled = notification_params[:enabled] == true || notification_params[:enabled] == "true"
    current_user.update(notifications_enabled: enabled)
    render json: { success: true, notifications_enabled: enabled }
  end

  def get_settings_state
    render json: {
      dark_mode: cookies[:dark_mode] == "true",
      notifications_enabled: current_user.notifications_enabled == true
    }
  end

  def delete_account
    current_user.destroy
    flash[:toast] = { message: "Conta excluída com sucesso.", type: "success" }
    redirect_to root_path
  end

  private

  def password_params
    params.permit(:current_password, :new_password, :password_confirmation)
  end

  def theme_params
    params.permit(:dark_mode)
  end

  def notification_params
    params.permit(:enabled)
  end
end
