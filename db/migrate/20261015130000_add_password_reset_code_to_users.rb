class AddPasswordResetCodeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :reset_password_code_digest, :string
    add_column :users, :reset_password_code_sent_at, :datetime
    add_column :users, :reset_password_code_attempts, :integer, default: 0, null: false
  end
end
