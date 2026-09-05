class CreateAdminAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_audit_logs do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :target_user, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :action, null: false
      t.string :details

      t.timestamps
    end

    add_index :admin_audit_logs, :created_at
  end
end
