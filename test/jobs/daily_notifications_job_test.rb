require "test_helper"

class DailyNotificationsJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = users(:one)
    @user.update!(notifications_enabled: true)
    plan = @user.training_plans.create!(
      goal: "Teste", status: "active", start_date: Date.new(2026, 9, 14),
      end_date: Date.new(2026, 10, 25), total_weeks: 6, plan_data: {}
    )
    @workout = plan.workouts.create!(
      week_number: 1, day_of_week: 3, scheduled_date: Date.new(2026, 9, 16),
      workout_type: "Corrida Leve", workout_format: "continuous",
      distance: 5.0, duration: 1800, pace: "6:00", status: "pending"
    )
  end

  test "as 19h lembra do treino de hoje com texto proprio" do
    travel_to Date.new(2026, 9, 16) do
      assert_difference -> { @user.notifications.count }, 1 do
        DailyNotificationsJob.new.perform
      end
    end

    notification = @user.notifications.last
    assert_equal "workout_reminder", notification.notification_type
    assert_includes notification.message, "Ainda dá tempo"
  end

  test "as 8h e as 19h mandam textos diferentes" do
    travel_to Date.new(2026, 9, 16) do
      WorkoutReminderJob.new.perform
      DailyNotificationsJob.new.perform
    end

    morning, evening = @user.notifications.order(:id).last(2)
    assert_not_equal morning.message, evening.message
  end

  test "as 19h nao dispara se o treino de hoje ja foi concluido" do
    @workout.update!(status: "completed")

    travel_to Date.new(2026, 9, 16) do
      assert_no_difference -> { @user.notifications.count } do
        DailyNotificationsJob.new.perform
      end
    end
  end

  test "nao manda mais lembrete de sincronizar o Strava" do
    @workout.update!(status: "completed")
    integration = strava_integrations(:one)
    integration.update_columns(active: true, last_sync_at: nil)
    assert @user.reload.strava_connected?

    travel_to Date.new(2026, 9, 16) do
      DailyNotificationsJob.new.perform
    end

    assert_equal 0, @user.notifications.where(notification_type: "sync_reminder").count
  end
end
