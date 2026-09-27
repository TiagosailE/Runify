require "test_helper"

class NotificationServiceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = users(:one)
    @user.update!(notifications_enabled: true)
    plan = @user.training_plans.create!(
      goal: "Teste", status: "active", start_date: Date.new(2026, 9, 14),
      end_date: Date.new(2026, 10, 25), total_weeks: 6, plan_data: {}
    )
    @continuous = plan.workouts.create!(
      week_number: 1, day_of_week: 3, scheduled_date: Date.new(2026, 9, 16),
      workout_type: "Corrida Leve", workout_format: "continuous",
      distance: 5.0, duration: 1800, pace: "6:00", status: "pending"
    )
    @run_walk = plan.workouts.create!(
      week_number: 1, day_of_week: 5, scheduled_date: Date.new(2026, 9, 18),
      workout_type: "Caminhada/Corrida", workout_format: "run_walk",
      distance: nil, duration: 1860, pace: "confortável", status: "pending"
    )
  end

  test "lembrete da manha cita o treino, sem horario" do
    NotificationService.send_workout_reminder(@user, @continuous)

    notification = @user.notifications.last
    assert_equal "workout_reminder", notification.notification_type
    assert_includes notification.message, "Corrida Leve"
    assert_includes notification.message, "5.0km"
    assert_no_match(/\d{2}:\d{2}/, notification.message)
    assert_no_match(/\bàs\b/, notification.message)
  end

  test "lembrete de treino sem distancia mostra a duracao, sem km vazio" do
    NotificationService.send_workout_reminder(@user, @run_walk)

    message = @user.notifications.last.message
    assert_includes message, "31min"
    assert_no_match(/km/, message)
    assert_no_match(/00:00/, message)
  end

  test "lembrete da noite tem texto proprio" do
    NotificationService.send_workout_reminder(@user, @continuous)
    NotificationService.send_evening_workout_reminder(@user, @continuous)

    morning, evening = @user.notifications.order(:id).last(2)
    assert_not_equal morning.title, evening.title
    assert_not_equal morning.message, evening.message
    assert_includes evening.message, "Ainda dá tempo"
    assert_includes evening.message, "Corrida Leve"
    assert_equal "workout_reminder", evening.notification_type
  end

  test "lembrete da noite de treino sem distancia mostra a duracao" do
    NotificationService.send_evening_workout_reminder(@user, @run_walk)

    message = @user.notifications.last.message
    assert_includes message, "31min"
    assert_no_match(/km|00:00/, message)
  end

  test "lembretes respeitam notifications_enabled desligado" do
    @user.update!(notifications_enabled: false)

    assert_no_difference -> { @user.notifications.count } do
      NotificationService.send_workout_reminder(@user, @continuous)
      NotificationService.send_evening_workout_reminder(@user, @continuous)
    end
  end

  test "resumo semanal conta os treinos da semana" do
    @continuous.update!(status: "completed")

    travel_to Date.new(2026, 9, 20) do # domingo da semana 1
      NotificationService.send_weekly_summary(@user)
    end

    assert_match(/1 de 2 treinos/, @user.notifications.last.message)
  end

  # Plano gerado no fim de semana nasce com a semana 1 vazia: "0 de 0" com
  # "Voce esta incrivel!" seria mentira.
  test "resumo semanal nao sai numa semana sem treino" do
    travel_to Date.new(2026, 9, 27) do # domingo da semana 3, sem treinos
      assert_no_difference -> { @user.notifications.count } do
        NotificationService.send_weekly_summary(@user)
      end
    end
  end

  test "o lembrete de sincronizacao do Strava deixou de existir" do
    assert_not_respond_to NotificationService, :send_sync_reminder
  end

  test "parabens cita o tipo do treino" do
    NotificationService.send_congratulations(@user, @continuous)

    notification = @user.notifications.last
    assert_equal "congratulations", notification.notification_type
    assert_includes notification.message, "Corrida Leve"
  end

  test "parabens respeita notifications_enabled desligado" do
    @user.update!(notifications_enabled: false)

    assert_no_difference -> { @user.notifications.count } do
      NotificationService.send_congratulations(@user, @continuous)
    end
  end

  test "alerta de ajuste sempre notifica, mesmo com notifications_enabled desligado" do
    @user.update!(notifications_enabled: false)

    assert_difference -> { @user.notifications.count }, 1 do
      NotificationService.send_adjustment_alert(@user, {
        "analysis" => "Aumentamos seu volume levemente.",
        "recommendations" => [ "Hidrate-se bem", "Durma cedo" ],
        "red_flags" => [ "dor no joelho" ]
      })
    end

    notification = @user.notifications.last
    assert_includes notification.message, "Aumentamos seu volume levemente."
    assert_includes notification.message, "Hidrate-se bem"
    assert_includes notification.message, "Alertas: dor no joelho"
  end
end
