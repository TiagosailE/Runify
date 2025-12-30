class CreateTrainingPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :training_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.text :goal
      t.string :status, default: 'active'
      t.date :start_date
      t.date :end_date
      t.integer :total_weeks
      t.jsonb :plan_data

      t.timestamps
    end

    add_index :training_plans, :status
    add_index :training_plans, :start_date
  end
end