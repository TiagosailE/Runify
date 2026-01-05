class CreateUserAchievements < ActiveRecord::Migration[8.0]
  def change
    create_table :user_achievements do |t|
      t.references :user, null: false, foreign_key: true
      t.references :achievement, null: false, foreign_key: true
      t.datetime :earned_at

      t.timestamps
    end

    add_index :user_achievements, [:user_id, :achievement_id], unique: true
  end
end