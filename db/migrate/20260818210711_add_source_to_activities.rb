class AddSourceToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :source, :string, default: "strava", null: false
  end
end
