class AddLastAdjustedWeekToTrainingPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :training_plans, :last_adjusted_week, :integer
  end
end
