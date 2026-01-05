class CreateSquads < ActiveRecord::Migration[8.0]
  def change
    create_table :squads do |t|
      t.string :name, null: false
      t.text :description
      t.integer :owner_id, null: false
      t.integer :challenge_duration
      t.date :challenge_start
      t.date :challenge_end
      t.string :squad_code, null: false

      t.timestamps
    end

    add_index :squads, :owner_id
    add_index :squads, :squad_code, unique: true
    add_index :squads, :challenge_start
  end
end