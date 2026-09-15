require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get settings_url
    assert_response :success
  end


  test "should get update_password" do
    post update_password_settings_url, params: {
      current_password: "password123",
      new_password: "newpassword123",
      password_confirmation: "newpassword123"
    }
    assert_redirected_to settings_path
  end

  test "should get toggle_theme" do
    post toggle_theme_settings_url
    assert_response :success
  end

  test "update_training_days salva os dias escolhidos" do
    post update_training_days_settings_url, params: { preferred_training_days: [ "2", "4", "6" ] }

    assert_redirected_to settings_path
    assert_equal [ 2, 4, 6 ], users(:one).reload.preferred_training_days
  end

  test "update_training_days rejeita lista vazia sem apagar a preferencia anterior" do
    users(:one).update!(preferred_training_days: [ 1, 3, 5 ])

    post update_training_days_settings_url, params: { preferred_training_days: [ "" ] }

    assert_redirected_to settings_path
    assert_equal [ 1, 3, 5 ], users(:one).reload.preferred_training_days
  end

  test "update_training_days regenera as semanas pendentes do plano ativo" do
    user = users(:one)
    user.update!(running_experience: "intermediate", weekly_mileage: 30, preferred_training_days: [ 1, 3, 5 ])
    plan = user.training_plans.create!(
      goal: "Teste", status: "active", start_date: 2.weeks.ago.to_date,
      end_date: Date.current + 4.weeks, total_weeks: 6, plan_data: {}
    )
    monday = plan.start_date.beginning_of_week(:monday)
    old_pending = plan.workouts.create!(
      week_number: plan.current_week, day_of_week: 1, scheduled_date: monday + (plan.current_week - 1).weeks,
      workout_type: "Corrida Leve", workout_format: "continuous", distance: 5.0, duration: 1800,
      pace: "6:00", description: "leve", instructions: "leve", status: "pending"
    )

    new_plan_data = {
      "analysis" => "continuacao", "plan_duration_weeks" => 6,
      "workouts" => [ {
        "week" => plan.current_week, "day" => 2, "type" => "Corrida Leve", "format" => "continuous",
        "distance_km" => 5.0, "duration_minutes" => 30, "pace" => "6:00",
        "description" => "leve", "instructions" => "leve"
      } ]
    }

    GeminiClient.stub :generate_json, ->(_prompt, **_opts) { new_plan_data } do
      post update_training_days_settings_url, params: { preferred_training_days: [ "2", "4" ] }
    end

    assert_redirected_to settings_path
    assert_not Workout.exists?(old_pending.id)
    assert_equal 1, plan.workouts.where(week_number: plan.current_week, day_of_week: 2).count
  end

  test "export_data devolve JSON com os dados do usuario" do
    user = users(:one)
    before_count = user.activities.count
    user.activities.create!(
      name: "Corrida", sport_type: "Run", distance: 5000, duration: 1800,
      moving_time: 1800, start_date: 2.days.ago, source: "manual"
    )

    get export_data_settings_url

    assert_response :success
    assert_equal "application/json", @response.media_type

    body = JSON.parse(@response.body)
    assert body["account"]["email"].present?
    assert_equal before_count + 1, body["activities"].size
    assert body.key?("strava_connected")
  end

  test "export_data nao inclui senha nem tokens de autenticacao" do
    get export_data_settings_url

    body = @response.body
    assert_not_includes body, users(:one).encrypted_password
    assert_not_includes body, "encrypted_password"
    assert_not_includes body, "reset_password_token"
  end
end
