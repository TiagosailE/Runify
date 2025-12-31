class ProfileController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def update
    age = params[:age].to_i
    birth_date = age > 0 ? Date.today - age.years : current_user.birth_date
    
    update_params = {
      username: params[:username],
      weight: params[:weight],
      height: params[:height],
      birth_date: birth_date,
      goal: params[:goal]
    }
    
    if params[:avatar].present?
      current_user.avatar.attach(params[:avatar])
    end
    
    if current_user.update(update_params)
      redirect_to profile_path, notice: "Perfil atualizado com sucesso!"
    else
      redirect_to profile_path, alert: "Erro ao atualizar perfil."
    end
  end
end