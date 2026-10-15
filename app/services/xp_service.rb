class XpService
  BASE_XP_PER_KM = 10
  WALK_XP_PER_KM = 5

  # Caminhada vale metade por km. Esteira e caminhada nao ganham bonus de
  # ritmo: na esteira a correia impoe o ritmo e a distancia e estimada pela
  # maquina, entao o ritmo calculado nao e confiavel o bastante para premiar.
  def self.calculate_xp(activity, squad_member)
    distance_km = activity.distance_km
    streak = squad_member.streak

    xp_per_km = activity.walk? ? WALK_XP_PER_KM : BASE_XP_PER_KM
    base_xp = (distance_km * xp_per_km).to_i
    pace_bonus = activity.walk? || activity.treadmill? ? 0 : calculate_pace_bonus(calculate_pace_minutes(activity))
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
    streak = calculate_streak(user)
    user.squad_members.each { |squad_member| squad_member.update(streak: streak) }
  end

  def self.calculate_streak(user)
    activity_dates = user.activities.runs_and_walks.select(:start_date).map { |activity| activity.start_date.to_date }.to_set
    return 0 if activity_dates.empty?

    today = Date.current
    cursor = activity_dates.include?(today) ? today : today - 1
    return 0 unless activity_dates.include?(cursor)

    streak = 0
    while activity_dates.include?(cursor)
      streak += 1
      cursor -= 1
    end
    streak
  end

  def self.calculate_pace_minutes(activity)
    return 6.0 unless activity.moving_time && activity.distance && activity.distance > 0

    pace_seconds = (activity.moving_time / (activity.distance / 1000.0))
    pace_seconds / 60.0
  end

  def self.calculate_pace_bonus(pace_minutes)
    bonus = (6.0 - pace_minutes) * 5
    [ [ bonus, 0 ].max, 25 ].min.to_i
  end

  def self.check_achievements(user, squad_member)
    if squad_member.level >= 10 && !user.achievements.exists?(name: "Nível 10")
      achievement = Achievement.find_or_create_by(
        name: "Nível 10",
        description: "Alcançou o nível 10",
        icon: "trophy",
        xp_reward: 100
      )
      user.user_achievements.create(achievement: achievement, earned_at: Time.current)
    end

    if squad_member.streak >= 7 && !user.achievements.exists?(name: "Semana Perfeita")
      achievement = Achievement.find_or_create_by(
        name: "Semana Perfeita",
        description: "7 dias consecutivos de treino",
        icon: "fire",
        xp_reward: 50
      )
      user.user_achievements.create(achievement: achievement, earned_at: Time.current)
    end
  end

  private_class_method :calculate_streak, :calculate_pace_minutes, :calculate_pace_bonus
end
