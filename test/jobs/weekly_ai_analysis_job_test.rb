require "test_helper"

class WeeklyAiAnalysisJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = users(:one)
    @user.update!(running_experience: "intermediate", weekly_mileage: 30)
    @plan = @user.training_plans.create!(
      goal: "Melhorar 10km", status: "active", start_date: Date.new(2026, 9, 7),
      end_date: Date.new(2026, 10, 18), total_weeks: 6, plan_data: {}
    )
    2.times do |index|
      @plan.workouts.create!(
        week_number: 1, day_of_week: index + 1, scheduled_date: Date.new(2026, 9, 7) + index.days,
        workout_type: "Corrida Leve", workout_format: "continuous",
        distance: 5.0, duration: 1800, pace: "6:00", status: "completed"
      )
    end
    @next_week = @plan.workouts.create!(
      week_number: 2, day_of_week: 1, scheduled_date: Date.new(2026, 9, 14),
      workout_type: "Corrida Leve", workout_format: "continuous",
      distance: 5.0, duration: 1800, pace: "6:00", status: "pending"
    )
  end

  def counting_gemini
    calls = 0
    fake = ->(_prompt, **_opts) do
      calls += 1
      {
        "analysis" => "análise", "adjustment_type" => "increase", "adjustment_percentage" => 10,
        "reasoning" => "motivo", "recommendations" => [], "red_flags" => []
      }
    end

    GeminiClient.stub :generate_json, fake do
      yield
    end

    calls
  end

  test "ajusta o plano na segunda e roda uma vez so por semana" do
    calls = counting_gemini do
      travel_to Date.new(2026, 9, 14) do
        WeeklyAiAnalysisJob.new.perform
        WeeklyAiAnalysisJob.new.perform
      end
    end

    assert_equal 1, calls
    assert_in_delta 5.5, @next_week.reload.distance.to_f, 0.001
    assert_equal 2, @plan.reload.last_adjusted_week
  end

  test "nao ajusta na primeira semana do plano" do
    calls = counting_gemini do
      travel_to(Date.new(2026, 9, 10)) { WeeklyAiAnalysisJob.new.perform }
    end

    assert_equal 0, calls
    assert_nil @plan.reload.last_adjusted_week
  end
end
