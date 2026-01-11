class PacersController < ApplicationController
  before_action :authenticate_user!

  def index
    @my_squads = current_user.squads
    @owned_squads = current_user.owned_squads
  end

  def new
    @squad = Squad.new
  end

  def create
    @squad = current_user.owned_squads.build(squad_params)
    
    if @squad.save
      @squad.squad_members.create(
        user: current_user,
        level: 1,
        experience_points: 0,
        streak: 0,
        joined_at: Time.current
      )
      
      redirect_to pacer_path(@squad), notice: 'Pacer criado com sucesso!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @squad = Squad.find(params[:id])
    @leaderboard = @squad.leaderboard.includes(:user)
    @is_member = @squad.users.include?(current_user)
    @my_squads = current_user.squads
  end

  def join
    squad = Squad.find_by(squad_code: params[:code])
    
    if squad.nil?
      redirect_to pacers_path, alert: 'Código inválido'
      return
    end

    if squad.users.include?(current_user)
      redirect_to pacer_path(squad), alert: 'Você já é membro deste Pacer'
      return
    end

    squad.squad_members.create(
      user: current_user,
      level: 1,
      experience_points: 0,
      streak: 0,
      joined_at: Time.current
    )

    redirect_to pacer_path(squad), notice: 'Você entrou no Pacer!'
  end

  def leave
    squad = Squad.find(params[:id])
    squad_member = squad.squad_members.find_by(user: current_user)
    
    if squad.owner == current_user
      redirect_to pacer_path(squad), alert: 'Você é o dono deste Pacer. Transfira a propriedade antes de sair.'
      return
    end

    squad_member&.destroy
    redirect_to pacers_path, notice: 'Você saiu do Pacer'
  end

  private

  def squad_params
    params.require(:squad).permit(:name, :description, :challenge_duration, :challenge_start, :challenge_end)
  end
end