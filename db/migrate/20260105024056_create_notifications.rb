class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :message
      t.string :notification_type
      t.boolean :read, default: false
      t.datetime :sent_at

      t.timestamps
    end

    add_index :notifications, :notification_type
    add_index :notifications, :read
    add_index :notifications, :sent_at
  end
end