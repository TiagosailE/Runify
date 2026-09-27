require "test_helper"

class WorkoutReminderJobTest < ActiveJob::TestCase
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
      workout_type: "Caminhada/Corrida", workout_format: "run_walk",
      distance: nil, duration: 1860, pace: "confortável", status: "pending"
    )
  end

  test "as 8h avisa do treino de hoje sem horario nem km vazio" do
    travel_to Date.new(2026, 9, 16) do
      assert_difference -> { @user.notifications.count }, 1 do
        WorkoutReminderJob.new.perform
      end
    end

    message = @user.notifications.last.message
    assert_includes message, "Caminhada/Corrida"
    assert_includes message, "31min"
    assert_no_match(/km|00:00/, message)
  end

  test "nao avisa quem desligou as notificacoes" do
    @user.update!(notifications_enabled: false)

    travel_to Date.new(2026, 9, 16) do
      assert_no_difference -> { @user.notifications.count } do
        WorkoutReminderJob.new.perform
      end
    end
  end
end
