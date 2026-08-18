class AddUniqueIndexToStravaIntegrationsAthleteId < ActiveRecord::Migration[8.1]
  def change
    remove_index :strava_integrations, :strava_athlete_id
    add_index :strava_integrations, :strava_athlete_id, unique: true
  end
end
