require "test_helper"

class TrainingPlanTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  def build_user
    User.create!(
      email: "plan-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      username: "Teste",
      terms_accepted: true
    )
  end

  # Bug real: current_week contava 7 dias a partir de start_date (o dia exato
  # da geracao), entao um plano gerado numa terca so virava de semana na
  # proxima terca -- fora de sincronia com scheduled_date, que usa a
  # segunda-feira como ancora. Isso fazia a tela mostrar um dia errado
  # como "hoje".
  test "current_week vira na segunda-feira, nao no aniversario do dia de geracao" do
    travel_to Date.new(2026, 9, 8) do # terca-feira: plano gerado hoje
      plan = TrainingPlan.create!(user: build_user, goal: "teste", status: "active", start_date: Date.current, total_weeks: 4)

      assert_equal 1, plan.current_week, "ainda na semana de geracao (terca)"
    end

    travel_to Date.new(2026, 9, 13) do # domingo da mesma semana de calendario
      plan = TrainingPlan.create!(user: build_user, goal: "teste", status: "active", start_date: Date.new(2026, 9, 8), total_weeks: 4)

      assert_equal 1, plan.current_week, "domingo ainda pertence a semana 1 (a semana de calendario nao vira ate segunda)"
    end

    travel_to Date.new(2026, 9, 14) do # segunda seguinte: fronteira real de semana
      plan = TrainingPlan.create!(user: build_user, goal: "teste", status: "active", start_date: Date.new(2026, 9, 8), total_weeks: 4)

      assert_equal 2, plan.current_week, "segunda-feira seguinte ja e semana 2, mesmo faltando um dia pra completar 7 desde a terca original"
    end
  end
end
