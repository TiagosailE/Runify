class CreateAchievements < ActiveRecord::Migration[8.0]
  def change
    create_table :achievements do |t|
      t.string :name, null: false
      t.text :description
      t.string :icon
      t.integer :xp_reward, default: 0
      t.string :badge_type

      t.timestamps
    end

    add_index :achievements, :badge_type
  end
end