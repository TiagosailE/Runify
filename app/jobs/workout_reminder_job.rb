class WorkoutReminderJob < ApplicationJob
  queue_as :default

  def perform
    User.where(notifications_enabled: true).find_each do |user|

      training_plan = user.active_training_plan
      next unless training_plan

      current_week = training_plan.current_week
      today_workouts = training_plan.workouts_for_week(current_week)
                                   .select { |w| w.scheduled_date == Date.today && w.pending? }

      today_workouts.each do |workout|
        NotificationService.send_workout_reminder(user, workout)
      end
    end
  end
end