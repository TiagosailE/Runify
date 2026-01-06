class NotificationService
  def self.send_workout_reminder(user, workout)
    return unless user.notifications_enabled?

    user.notifications.create(
      title: "Treino de Hoje! 🏃",
      message: "Você tem um treino agendado: #{workout.workout_type} - #{workout.distance_km}km às #{workout.scheduled_date.strftime('%H:%M')}",
      notification_type: 'workout_reminder',
      sent_at: Time.current
    )
  end

  def self.send_sync_reminder(user)
    return unless user.notifications_enabled?

    user.notifications.create(
      title: "Sincronize seu Strava 🔄",
      message: "Já faz um tempo que você não sincroniza suas atividades. Que tal atualizar?",
      notification_type: 'sync_reminder',
      sent_at: Time.current
    )
  end

  def self.send_congratulations(user, workout)
    return unless user.notifications_enabled?

    messages = [
      "Você completou o treino: #{workout.workout_type}. Continue assim! 💪",
      "Parabéns! Mais um treino concluído: #{workout.workout_type}! 🎉",
      "Excelente trabalho! #{workout.workout_type} completado! 🏆",
      "Você está arrasando! #{workout.workout_type} feito! 🔥"
    ]

    user.notifications.create(
      title: "Parabéns! 🎉",
      message: messages.sample,
      notification_type: 'congratulations',
      sent_at: Time.current
    )
  end

  def self.send_weekly_summary(user)
    return unless user.notifications_enabled?

    training_plan = user.active_training_plan
    return unless training_plan

    current_week = training_plan.current_week
    week_workouts = training_plan.workouts_for_week(current_week)
    completed = week_workouts.count(&:completed?)
    total = week_workouts.count

    motivation = if completed >= total * 0.8
      "Você está incrível! 🌟"
    elsif completed >= total * 0.5
      "Ótimo trabalho! Continue assim! 💪"
    else
      "Vamos buscar mais na próxima semana! 💪"
    end

    user.notifications.create(
      title: "Resumo Semanal 📊",
      message: "Você completou #{completed} de #{total} treinos esta semana. #{motivation}",
      notification_type: 'weekly_summary',
      sent_at: Time.current
    )
  end
end