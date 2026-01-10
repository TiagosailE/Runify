class ProfileController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def update
    update_params = {
      username: params[:user][:username],
      weight: params[:user][:weight],
      height: params[:user][:height],
      goal: params[:user][:goal]
    }

    if params[:user][:age].present? && params[:user][:age].to_i > 0
      age = params[:user][:age].to_i
      update_params[:birth_date] = Date.today - age.years
    end
    
    if params[:user][:avatar].present?
      current_user.avatar.attach(params[:user][:avatar])
    end
    
    if current_user.update(update_params)
      flash[:toast] = { message: 'Perfil atualizado com sucesso!', type: 'success' }
      redirect_to profile_path
    else
      flash[:toast] = { message: "Erro ao atualizar perfil: #{current_user.errors.full_messages.join(', ')}", type: 'error' }
      redirect_to profile_path
    end
  end
end