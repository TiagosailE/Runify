class AddWorkoutFormatToWorkouts < ActiveRecord::Migration[8.1]
  def change
    # Distingue corrida continua de caminhada/corrida alternadas. Sem esta
    # coluna o discriminador seria "existe a chave steps no jsonb?", que e
    # estado implicito. Linhas ja existentes sao todas continuas.
    add_column :workouts, :workout_format, :string, null: false, default: "continuous"
  end
end
