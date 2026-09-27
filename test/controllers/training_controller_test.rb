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

  test "generate mostra mensagem generica sem o detalhe da excecao" do
    boom = ->(*) { raise "detalhe interno que nao pode vazar" }

    AiTrainingService.stub :new, boom do
      post generate_training_url
    end

    assert_redirected_to training_index_path
    assert_no_match "detalhe interno que nao pode vazar", flash[:toast][:message]
  end

  test "should get complete" do
    post training_complete_url(workouts(:one))
    assert_response :success
  end

  test "usuario nao completa treino de outro usuario" do
    post training_complete_url(workouts(:two))
    assert_response :not_found
  end

  test "usuario nao envia feedback de treino de outro usuario" do
    post training_feedback_url(workouts(:two)), params: { difficulty: "medium", notes: "ok" }
    assert_response :not_found
  end

  test "should get feedback" do
    post training_feedback_url(workouts(:one)), params: { difficulty: "medium", notes: "ok" }
    assert_response :success
  end

  # O ajuste da IA roda so no job de segunda: o feedback apenas grava.
  test "feedback grava sem chamar o ajuste da IA mesmo com tres treinos concluidos na semana" do
    monday = Date.new(2026, 9, 14)
    plan = users(:one).training_plans.create!(
      goal: "Teste", status: "active", start_date: monday - 1.week,
      end_date: monday + 5.weeks, total_weeks: 6, plan_data: {}
    )
    workouts = [ 0, 1, 2 ].map do |offset|
      plan.workouts.create!(
        week_number: 2, day_of_week: offset + 1, scheduled_date: monday + offset.days,
        workout_type: "Corrida Leve", workout_format: "continuous", distance: 5.0, duration: 1800,
        pace: "6:00", description: "leve", instructions: "leve", status: "completed"
      )
    end

    boom = ->(*) { raise "o feedback nao deveria chamar o ajuste da IA" }

    travel_to monday + 2.days do
      AiAdjustmentService.stub :new, boom do
        post training_feedback_url(workouts.last), params: { difficulty: "facil", notes: "ok" }
      end
    end

    assert_response :success
    assert_equal "facil", workouts.last.reload.workout_details.dig("user_feedback", "difficulty")
  end
end
