require "test_helper"

class TrainingControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get training_index_url
    assert_response :success
  end

  # Plano com start_date numa quinta (como os gerados antes da correcao): na
  # segunda seguinte e a semana 2 e o treino do dia precisa aparecer (antes
  # current_week seguia em 1 e o treino sumia).
  test "index mostra o treino de hoje na segunda seguinte a um plano gerado no meio da semana" do
    plan = users(:one).training_plans.create!(
      goal: "Teste", status: "active", start_date: Date.new(2026, 9, 10),
      end_date: Date.new(2026, 10, 21), total_weeks: 6, plan_data: {}
    )
    plan.workouts.create!(
      week_number: 2, day_of_week: 1, scheduled_date: Date.new(2026, 9, 14),
      workout_type: "Corrida Leve", workout_format: "continuous", distance: 5.0, duration: 1800,
      pace: "6:00", description: "Treino da segunda", instructions: "leve", status: "pending"
    )

    travel_to Date.new(2026, 9, 14) do
      get training_index_url
    end

    assert_response :success
    assert_select "h2", text: /Semana 2 de 6/
    assert_select "p", text: "Treino de hoje"
    assert_select "p", text: "Treino da segunda"
  end

  test "should get show" do
    get training_show_url(workouts(:one))
    assert_response :success
  end

  test "should get complete" do
    post training_complete_url(workouts(:one))
    assert_response :success
  end

  test "should get feedback" do
    post training_feedback_url(workouts(:one)), params: { difficulty: "medium", notes: "ok" }
    assert_response :success
  end
end
