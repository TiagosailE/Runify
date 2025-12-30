class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :strava_activity_id
      t.string :name
      t.string :sport_type
      t.decimal :distance, precision: 8, scale: 2
      t.integer :duration
      t.integer :moving_time
      t.string :pace
      t.decimal :average_speed, precision: 5, scale: 2
      t.datetime :start_date
      t.jsonb :activity_data

      t.timestamps
    end

    unless index_exists?(:activities, :user_id)
      add_index :activities, :user_id
    end

    unless index_exists?(:activities, :strava_activity_id)
      add_index :activities, :strava_activity_id, unique: true
    end

    unless index_exists?(:activities, :start_date)
      add_index :activities, :start_date
    end
  end
end