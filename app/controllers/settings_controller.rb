class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @dark_mode = cookies[:dark_mode] == 'true'
    @notifications_enabled = current_user.notifications_enabled
  end

  def update_password
    if current_user.valid_password?(params[:current_password])
      if params[:new_password] == params[:password_confirmation]
        if current_user.update(password: params[:new_password], password_confirmation: params[:password_confirmation])
          bypass_sign_in(current_user)
          flash[:toast] = { message: 'Senha alterada com sucesso!', type: 'success' }
          redirect_to settings_path
        else
          flash[:toast] = { message: current_user.errors.full_messages.join(', '), type: 'error' }
          redirect_to settings_path
        end
      else
        flash[:toast] = { message: 'As senhas não coincidem.', type: 'error' }
        redirect_to settings_path
      end
    else
      flash[:toast] = { message: 'Senha atual incorreta.', type: 'error' }
      redirect_to settings_path
    end
  end

  def toggle_theme
    dark_mode = params[:dark_mode] == true || params[:dark_mode] == 'true'
    cookies.permanent[:dark_mode] = dark_mode
    render json: { success: true, dark_mode: dark_mode }
  end

  def toggle_notifications
    enabled = params[:enabled] == true || params[:enabled] == 'true'
    current_user.update(notifications_enabled: enabled)
    render json: { success: true, notifications_enabled: enabled }
  end

  def get_settings_state
    render json: {
      dark_mode: cookies[:dark_mode] == 'true',
      notifications_enabled: current_user.notifications_enabled == true
    }
  end

  def delete_account
    current_user.destroy
    flash[:toast] = { message: 'Conta excluída com sucesso.', type: 'success' }
    redirect_to root_path
  end
end