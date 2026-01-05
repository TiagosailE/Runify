class NotificationService
  def self.send_workout_reminder(user, workout)
    return unless user.notifications_enabled?

    user.notifications.create(
      title: "Treino de Hoje!",
      message: "Você tem um treino agendado: #{workout.workout_type} - #{workout.distance_km}km",
      notification_type: 'workout_reminder',
      sent_at: Time.current
    )
  end

  def self.send_sync_reminder(user)
    return unless user.notifications_enabled?

    user.notifications.create(
      title: "Sincronize seu Strava",
      message: "Já faz um tempo que você não sincroniza suas atividades. Que tal atualizar?",
      notification_type: 'sync_reminder',
      sent_at: Time.current
    )
  end

  def self.send_congratulations(user, workout)
    return unless user.notifications_enabled?

    user.notifications.create(
      title: "Parabéns!",
      message: "Você completou o treino: #{workout.workout_type}. Continue assim!",
      notification_type: 'congratulations',
      sent_at: Time.current
    )
  end

  def self.send_weekly_summary(user)
    return unless user.notifications_enabled?

    current_week = user.active_training_plan&.current_week
    return unless current_week

    completed = user.active_training_plan.workouts_for_week(current_week).count(&:completed?)
    total = user.active_training_plan.workouts_for_week(current_week).count

    user.notifications.create(
      title: "Resumo Semanal",
      message: "Você completou #{completed} de #{total} treinos esta semana. #{completed >= 3 ? 'Ótimo trabalho!' : 'Vamos buscar mais!'}",
      notification_type: 'weekly_summary',
      sent_at: Time.current
    )
  end
end