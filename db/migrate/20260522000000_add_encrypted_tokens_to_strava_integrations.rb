class AddEncryptedTokensToStravaIntegrations < ActiveRecord::Migration[8.1]
  def change
    rename_column :strava_integrations, :access_token, :access_token_ciphertext
    rename_column :strava_integrations, :refresh_token, :refresh_token_ciphertext
  end
end
