class CreateStravaIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :strava_integrations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :strava_athlete_id
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_sync_at
      t.boolean :active, default: true
      t.jsonb :athlete_data

      t.timestamps
    end

    unless index_exists?(:strava_integrations, :user_id)
      add_index :strava_integrations, :user_id, unique: true
    end

    unless index_exists?(:strava_integrations, :strava_athlete_id)
      add_index :strava_integrations, :strava_athlete_id
    end
  end
end