require "test_helper"

class TrainingControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get training_index_url
    assert_response :success
  end

  test "should get show" do
    get training_show_url(workouts(:one))
    assert_response :success
  end

  test "should get complete" do
    post training_complete_url(workouts(:one))
    assert_response :success
  end

  # Bug real reportado: dava pra marcar como concluido um treino agendado
  # para o futuro, so clicando no dia errado do calendario.
  test "nao deixa completar treino agendado para o futuro" do
    future_workout = training_plans(:one).workouts.create!(
      week_number: 1, day_of_week: 1, scheduled_date: Date.current + 3.days,
      workout_type: "Corrida Leve", workout_format: "continuous",
      distance: 5.0, duration: 1800, pace: "6:00", status: "pending"
    )

    post training_complete_url(future_workout)

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_not body["success"]
    assert_match(/ainda não chegou/, body["message"])
    assert_equal "pending", future_workout.reload.status
  end

  test "should get feedback" do
    post training_feedback_url(workouts(:one)), params: { difficulty: "medium", notes: "ok" }
    assert_response :success
  end
end
