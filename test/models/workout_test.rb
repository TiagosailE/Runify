require "test_helper"

# Ultima linha de defesa: mesmo que validador e envelope falhem, um treino
# impossivel nao pode ser gravado.
class WorkoutTest < ActiveSupport::TestCase
  def build_workout(**attrs)
    training_plans(:one).workouts.build(
      {
        week_number: 1,
        day_of_week: 1,
        scheduled_date: Date.today,
        workout_type: "Corrida Leve",
        workout_format: "continuous",
        distance: 5.0,
        duration: 1800,
        pace: "6:00",
        status: "pending"
      }.merge(attrs)
    )
  end

  test "treino contínuo válido é aceito" do
    assert build_workout.valid?
  end

  test "rejeita distância impossível" do
    assert_not build_workout(distance: 500).valid?
  end

  test "rejeita distância zero ou negativa" do
    assert_not build_workout(distance: 0).valid?
    assert_not build_workout(distance: -3).valid?
  end

  test "rejeita duração absurda" do
    assert_not build_workout(duration: 20.hours.to_i).valid?
  end

  test "rejeita dia da semana fora de 1 a 7" do
    assert_not build_workout(day_of_week: 0).valid?
    assert_not build_workout(day_of_week: 9).valid?
  end

  test "rejeita formato desconhecido" do
    assert_not build_workout(workout_format: "teleporte").valid?
  end

  test "corrida contínua exige distância" do
    workout = build_workout(distance: nil)

    assert_not workout.valid?
    assert workout.errors[:distance].any?
  end

  test "caminhada corrida é válida sem distância" do
    assert build_workout(workout_format: "run_walk", distance: nil).valid?
  end

  test "steps devolve lista vazia quando não há blocos" do
    assert_equal [], build_workout.steps
  end

  test "steps devolve os blocos gravados no jsonb" do
    steps = [ { "activity" => "run", "seconds" => 60, "repeat" => 8 } ]
    workout = build_workout(workout_format: "run_walk", distance: nil, workout_details: { "steps" => steps })

    assert_equal steps, workout.steps
  end
end
