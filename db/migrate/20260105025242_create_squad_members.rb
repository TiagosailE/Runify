class CreateSquadMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :squad_members do |t|
      t.references :squad, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :level, default: 1
      t.integer :experience_points, default: 0
      t.integer :streak, default: 0
      t.datetime :joined_at

      t.timestamps
    end

    add_index :squad_members, [:squad_id, :user_id], unique: true
    add_index :squad_members, :experience_points
    add_index :squad_members, :level
  end
end