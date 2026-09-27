class AddForeignKeyToSquadsOwnerId < ActiveRecord::Migration[8.1]
  def up
    orphans = execute(<<~SQL).to_a
      SELECT squads.id FROM squads
      LEFT JOIN users ON users.id = squads.owner_id
      WHERE users.id IS NULL
    SQL

    if orphans.any?
      squad_ids = orphans.map { |row| row["id"] }.join(", ")
      raise "squad(s) #{squad_ids} tem owner_id sem usuario correspondente. Resolva antes de aplicar esta migration."
    end

    change_column :squads, :owner_id, :bigint
    add_foreign_key :squads, :users, column: :owner_id, validate: false
    validate_foreign_key :squads, :users, column: :owner_id
  end

  def down
    remove_foreign_key :squads, :users, column: :owner_id
    change_column :squads, :owner_id, :integer
  end
end
