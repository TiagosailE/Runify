class ProfileController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def update
    update_params = profile_params.slice(:username, :weight, :height, :goal)

    if profile_params[:age].present? && profile_params[:age].to_i > 0
      age = profile_params[:age].to_i
      update_params[:birth_date] = Date.today - age.years
    end

    if profile_params[:avatar].present?
      current_user.avatar.attach(profile_params[:avatar])
    end

    if current_user.update(update_params)
      flash[:toast] = { message: 'Perfil atualizado com sucesso!', type: 'success' }
      redirect_to profile_path
    else
      flash[:toast] = { message: "Erro ao atualizar perfil: #{current_user.errors.full_messages.join(', ')}", type: 'error' }
      redirect_to profile_path
    end
  end

  private

  def profile_params
    params.require(:user).permit(:username, :weight, :height, :goal, :age, :avatar)
  end
end
