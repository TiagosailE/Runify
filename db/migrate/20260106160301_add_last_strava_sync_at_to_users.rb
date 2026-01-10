class AddLastStravaSyncAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_strava_sync_at, :datetime
  end
end
