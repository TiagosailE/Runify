require "test_helper"

class TrainingPlanTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  # 2026-09-10 e uma quinta-feira; a segunda dessa semana e 2026-09-07.
  def plan_started_on_thursday
    users(:one).training_plans.create!(
      goal: "Teste", status: "active", start_date: Date.new(2026, 9, 10),
      end_date: Date.new(2026, 11, 1), total_weeks: 6, plan_data: {}
    )
  end

  test "current_week conta a partir da segunda-feira da semana do start_date" do
    plan = plan_started_on_thursday

    travel_to Date.new(2026, 9, 10) do
      assert_equal 1, plan.current_week
    end

    travel_to Date.new(2026, 9, 13) do # domingo, ainda a semana 1
      assert_equal 1, plan.current_week
    end

    travel_to Date.new(2026, 9, 14) do # segunda seguinte
      assert_equal 2, plan.current_week
    end
  end

  test "current_week de um plano que comeca numa segunda vira 2 na segunda seguinte" do
    plan = plan_started_on_thursday
    plan.update!(start_date: Date.new(2026, 9, 7))

    travel_to(Date.new(2026, 9, 13)) { assert_equal 1, plan.current_week }
    travel_to(Date.new(2026, 9, 14)) { assert_equal 2, plan.current_week }
  end

  test "current_week e zero sem start_date" do
    assert_equal 0, TrainingPlan.new.current_week
  end
end
