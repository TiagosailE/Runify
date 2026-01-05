class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @dark_mode = cookies[:dark_mode] == 'true'
  end

  def update_password
    if current_user.valid_password?(params[:current_password])
      if params[:new_password] == params[:password_confirmation]
        if current_user.update(password: params[:new_password], password_confirmation: params[:password_confirmation])
          bypass_sign_in(current_user)
          redirect_to settings_path, notice: 'Senha alterada com sucesso!'
        else
          redirect_to settings_path, alert: current_user.errors.full_messages.join(', ')
        end
      else
        redirect_to settings_path, alert: 'As senhas não coincidem.'
      end
    else
      redirect_to settings_path, alert: 'Senha atual incorreta.'
    end
  end

  def toggle_theme
    dark_mode = params[:dark_mode] == 'true'
    cookies.permanent[:dark_mode] = dark_mode
    render json: { success: true, dark_mode: dark_mode }
  end

  def toggle_notifications
    enabled = params[:enabled] == 'true'
    current_user.update(notifications_enabled: enabled)
    render json: { success: true, notifications_enabled: enabled }
  end

  def delete_account
    current_user.destroy
    redirect_to root_path, notice: 'Conta excluída com sucesso.'
  end
end