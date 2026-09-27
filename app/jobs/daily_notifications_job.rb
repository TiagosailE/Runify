class DailyNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    User.where(notifications_enabled: true).find_each do |user|
      send_evening_reminder(user)
    end
  end

  private

  def send_evening_reminder(user)
    training_plan = user.active_training_plan
    return unless training_plan

    today_workout = training_plan.workouts.find_by(
      scheduled_date: Date.current,
      status: "pending"
    )

    if today_workout
      NotificationService.send_evening_workout_reminder(user, today_workout)
    end
  end
end
