class DailyNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    User.where(notifications_enabled: true).find_each do |user|
      send_workout_reminder(user)
      check_sync_reminder(user)
    end
  end

  private

  def send_workout_reminder(user)
    training_plan = user.active_training_plan
    return unless training_plan

    today_workout = training_plan.workouts.find_by(
      scheduled_date: Date.today,
      status: 'pending'
    )

    if today_workout
      NotificationService.send_workout_reminder(user, today_workout)
    end
  end

  def check_sync_reminder(user)
    return unless user.strava_connected?

    last_sync = user.strava_integration.last_sync_at
    
    if last_sync.nil? || last_sync < 3.days.ago
      NotificationService.send_sync_reminder(user)
    end
  end
end