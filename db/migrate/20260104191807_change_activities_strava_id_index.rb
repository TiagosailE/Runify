class ChangeActivitiesStravaIdIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :activities, :strava_activity_id if index_exists?(:activities, :strava_activity_id)
    
    add_index :activities, [:user_id, :strava_activity_id], unique: true, name: 'index_activities_on_user_and_strava_id'
  end
end