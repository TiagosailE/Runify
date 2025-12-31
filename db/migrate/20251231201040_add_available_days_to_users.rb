class AddAvailableDaysToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :available_days, :jsonb
  end
end
