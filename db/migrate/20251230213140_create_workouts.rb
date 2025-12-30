class CreateWorkouts < ActiveRecord::Migration[8.0]
  def change
    create_table :workouts do |t|
      t.references :training_plan, null: false, foreign_key: true
      t.integer :week_number
      t.integer :day_of_week
      t.date :scheduled_date
      t.string :workout_type
      t.decimal :distance, precision: 8, scale: 2
      t.integer :duration
      t.string :pace
      t.text :description
      t.text :instructions
      t.jsonb :workout_details
      t.string :status, default: 'pending'

      t.timestamps
    end

    add_index :workouts, :scheduled_date
    add_index :workouts, :status
    add_index :workouts, [:training_plan_id, :week_number]
  end
end