class AddTreadmillToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :treadmill, :boolean, default: false, null: false
    add_column :activities, :incline_percent, :decimal, precision: 3, scale: 1
  end
end
