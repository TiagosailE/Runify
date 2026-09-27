class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    @my_squads = current_user.squads.includes(squad_members: :user)

    @squads_with_leaderboard = @my_squads.map do |squad|
      top3 = squad.leaderboard.includes(:user).first(3)
      week_start = 7.days.ago.beginning_of_day
      members_with_km = squad.squad_members.includes(:user).map do |member|
        week_km = member.user.activities
                        .runs
                        .where("start_date >= ?", week_start)
                        .sum(:distance)
        week_km = (week_km / 1000.0).round(1)
        { member: member, week_km: week_km }
      end.sort_by { |m| -m[:week_km] }

      {
        squad: squad,
        top3: top3,
        members_with_km: members_with_km
      }
    end
  end
end
