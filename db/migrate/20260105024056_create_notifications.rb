class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :message, null: false
      t.string :notification_type, null: false
      t.boolean :read, default: false, null: false
      t.datetime :sent_at

      t.timestamps
    end

    add_index :notifications, [:user_id, :read]
    add_index :notifications, :notification_type
    add_index :notifications, :sent_at
  end
end