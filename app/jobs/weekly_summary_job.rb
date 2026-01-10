class WeeklySummaryJob < ApplicationJob
  queue_as :default

  def perform
    User.where(notifications_enabled: true).find_each do |user|
      NotificationService.send_weekly_summary(user)
    end
  end
end