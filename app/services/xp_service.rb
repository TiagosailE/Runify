class XpService
  BASE_XP_PER_KM = 10

  def self.calculate_xp(activity, squad_member)
    distance_km = activity.distance_km
    pace = calculate_pace_minutes(activity)
    streak = squad_member.streak

    base_xp = (distance_km * BASE_XP_PER_KM).to_i
    pace_bonus = calculate_pace_bonus(pace)
    streak_bonus = streak * 10

    total_xp = base_xp + pace_bonus + streak_bonus

    total_xp
  end

  def self.award_xp(user, activity)
    user.squad_members.each do |squad_member|
      next unless squad_member.squad.active?

      xp = calculate_xp(activity, squad_member)
      squad_member.add_xp(xp)

      check_achievements(user, squad_member)
    end
  end

  def self.update_streak(user)
    user.squad_members.each do |squad_member|
      last_workout = user.activities.where('start_date >= ?', 2.days.ago).exists?
      
      if last_workout
        squad_member.increment!(:streak)
      else
        squad_member.update(streak: 0)
      end
    end
  end

  private

  def self.calculate_pace_minutes(activity)
    return 6.0 unless activity.moving_time && activity.distance && activity.distance > 0
    
    pace_seconds = (activity.moving_time / (activity.distance / 1000.0))
    pace_seconds / 60.0
  end

  def self.calculate_pace_bonus(pace_minutes)
    bonus = (6.0 - pace_minutes) * 5
    [[bonus, 0].max, 25].min.to_i
  end

  def self.check_achievements(user, squad_member)
    if squad_member.level == 10 && !user.achievements.exists?(name: 'Nível 10')
      achievement = Achievement.find_or_create_by(
        name: 'Nível 10',
        description: 'Alcançou o nível 10',
        icon: 'trophy',
        xp_reward: 100
      )
      user.user_achievements.create(achievement: achievement, earned_at: Time.current)
    end

    if squad_member.streak >= 7 && !user.achievements.exists?(name: 'Semana Perfeita')
      achievement = Achievement.find_or_create_by(
        name: 'Semana Perfeita',
        description: '7 dias consecutivos de treino',
        icon: 'fire',
        xp_reward: 50
      )
      user.user_achievements.create(achievement: achievement, earned_at: Time.current)
    end
  end
end