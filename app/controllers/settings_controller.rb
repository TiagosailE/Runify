class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @dark_mode = cookies[:dark_mode] == 'true'
  end

  def update_password
    if current_user.valid_password?(params[:current_password])
      if current_user.update(password: params[:new_password], password_confirmation: params[:password_confirmation])
        bypass_sign_in(current_user)
        redirect_to settings_path, notice: 'Senha alterada com sucesso!'
      else
        redirect_to settings_path, alert: 'Erro ao alterar senha. Verifique se as senhas coincidem.'
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

  def delete_account
    current_user.destroy
    redirect_to root_path, notice: 'Conta excluída com sucesso.'
  end
end