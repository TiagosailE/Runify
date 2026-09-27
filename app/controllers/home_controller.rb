class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    @my_squads = current_user.squads.includes(squad_members: :user)
    week_start = 7.days.ago.beginning_of_day
    member_user_ids = @my_squads.flat_map { |squad| squad.squad_members.map(&:user_id) }.uniq
    week_km_by_user_id = Activity.runs
                                  .where(user_id: member_user_ids, start_date: week_start..)
                                  .group(:user_id)
                                  .sum(:distance)

    @squads_with_leaderboard = @my_squads.map do |squad|
      top3 = squad.leaderboard.includes(:user).first(3)
      members_with_km = squad.squad_members.includes(:user).map do |member|
        week_km = (week_km_by_user_id[member.user_id].to_f / 1000.0).round(1)
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
