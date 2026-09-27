class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @dark_mode = cookies[:dark_mode] == "true"
    @notifications_enabled = current_user.notifications_enabled
    @training_days = current_user.preferred_training_days
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

  def update_training_days
    days = training_days_params[:preferred_training_days].to_a.reject(&:blank?).map(&:to_i).select { |d| d.between?(1, 7) }.uniq.sort

    if days.empty?
      flash[:toast] = { message: "Selecione pelo menos um dia de treino.", type: "error" }
      return redirect_to settings_path
    end

    current_user.update!(preferred_training_days: days)
    RegenerateTrainingDaysJob.perform_later(current_user.id)

    flash[:toast] = { message: "Dias de treino atualizados! Seu plano está sendo ajustado em segundo plano.", type: "success" }
    redirect_to settings_path
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

  # Portabilidade (LGPD Art. 18, V). Exclui senha e tokens do Strava --
  # nao sao "dado sobre o titular", e expor token de terceiro seria falha
  # de seguranca.
  def export_data
    data = {
      exported_at: Time.current.iso8601,
      account: current_user.as_json(
        except: %w[encrypted_password reset_password_token reset_password_sent_at remember_created_at]
      ),
      activities: current_user.activities.as_json,
      training_plans: current_user.training_plans.as_json(include: :workouts),
      squads: current_user.squads.as_json(only: [ :id, :name, :squad_code ]),
      achievements: current_user.achievements.as_json(only: [ :id, :name, :description ]),
      strava_connected: current_user.strava_connected?
    }

    send_data JSON.pretty_generate(data),
      filename: "runify-meus-dados-#{Date.current.iso8601}.json",
      type: "application/json",
      disposition: "attachment"
  end

  # A senha, quando certa, sempre confirma -- inclusive numa conta que
  # vinculou o Google depois de criada com senha (OmniauthCallbacksController
  # so grava o provider, nunca mexe na senha real que o usuario ja tinha). O
  # e-mail so entra como confirmacao alternativa pra quem tem provider e pode
  # nao ter senha nenhuma pra digitar (cadastro direto pelo Google).
  def delete_account
    confirmation = delete_account_params[:confirmation].to_s
    confirmed = current_user.valid_password?(confirmation) ||
      (current_user.provider.present? && current_user.email.casecmp?(confirmation))

    if confirmed
      current_user.destroy
      flash[:toast] = { message: "Conta excluída com sucesso.", type: "success" }
      redirect_to root_path
    else
      message = current_user.provider.present? ? "Senha ou e-mail incorretos." : "Senha incorreta."
      flash[:toast] = { message: "#{message} Nada foi excluído.", type: "error" }
      redirect_to settings_path
    end
  end

  private

  def delete_account_params
    params.permit(:confirmation)
  end

  def training_days_params
    params.permit(preferred_training_days: [])
  end

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
