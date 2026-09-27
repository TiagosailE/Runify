require "test_helper"
require "fugit"

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

  test "nao chama o servico para plano ja ajustado na semana" do
    instantiations = 0
    fake_service = Object.new
    fake_service.define_singleton_method(:analyze_and_adjust) { nil }
    build = ->(*_args) do
      instantiations += 1
      fake_service
    end

    AiAdjustmentService.stub :new, build do
      travel_to Date.new(2026, 9, 14) do
        @plan.update!(last_adjusted_week: 2)
        WeeklyAiAnalysisJob.new.perform
        assert_equal 0, instantiations

        @plan.update!(last_adjusted_week: 1)
        WeeklyAiAnalysisJob.new.perform
        assert_equal 1, instantiations
      end
    end
  end

  test "agenda a analise de segunda a quarta, as 6h de Brasilia" do
    options = Rails.application.config_for(:recurring, env: "production")[:weekly_ai_analysis]
    schedule = Fugit.parse("#{options[:schedule]} #{SolidQueue.time_zone}", multi: :fail)

    time = Time.find_zone("Brasilia").local(2026, 9, 13)
    runs = Array.new(7) { time = schedule.next_time(time).to_t.in_time_zone("Brasilia") }

    assert_equal [ 1, 2, 3, 1, 2, 3, 1 ], runs.map(&:wday)
    assert runs.all? { |run| run.hour == 6 && run.min.zero? }
  end

  test "nao ajusta na primeira semana do plano" do
    calls = counting_gemini do
      travel_to(Date.new(2026, 9, 10)) { WeeklyAiAnalysisJob.new.perform }
    end

    assert_equal 0, calls
    assert_nil @plan.reload.last_adjusted_week
  end
end
