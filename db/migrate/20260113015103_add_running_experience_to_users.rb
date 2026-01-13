class AddRunningExperienceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :running_experience, :string
    add_column :users, :running_experience_years, :integer
    add_column :users, :best_5k_time, :integer
    add_column :users, :best_10k_time, :integer
    add_column :users, :best_half_marathon_time, :integer
    add_column :users, :weekly_mileage, :decimal, precision: 5, scale: 2
    add_column :users, :injury_history, :text
    add_column :users, :preferred_training_days, :integer, array: true, default: []
  end
end