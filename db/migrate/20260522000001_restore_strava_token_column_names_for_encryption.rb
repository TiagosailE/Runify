class RestoreStravaTokenColumnNamesForEncryption < ActiveRecord::Migration[8.1]
  def change
    rename_column :strava_integrations, :access_token_ciphertext, :access_token
    rename_column :strava_integrations, :refresh_token_ciphertext, :refresh_token
  end
end
