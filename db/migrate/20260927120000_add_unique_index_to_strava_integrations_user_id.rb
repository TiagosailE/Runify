class AddUniqueIndexToStravaIntegrationsUserId < ActiveRecord::Migration[8.1]
  def up
    duplicates = execute(<<~SQL).to_a
      SELECT user_id, count(*) FROM strava_integrations GROUP BY user_id HAVING count(*) > 1
    SQL

    if duplicates.any?
      user_ids = duplicates.map { |row| row["user_id"] }.join(", ")
      raise "strava_integrations tem mais de uma linha para o(s) user_id #{user_ids}. Resolva antes de aplicar esta migration."
    end

    remove_index :strava_integrations, :user_id
    add_index :strava_integrations, :user_id, unique: true
  end

  def down
    remove_index :strava_integrations, :user_id
    add_index :strava_integrations, :user_id
  end
end
