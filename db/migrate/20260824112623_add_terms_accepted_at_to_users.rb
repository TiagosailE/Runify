class AddTermsAcceptedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :terms_accepted_at, :datetime

    # Contas anteriores ao checkbox: sem aceite real para coletar, usa a
    # data de criacao como marco de referencia.
    execute "UPDATE users SET terms_accepted_at = created_at WHERE terms_accepted_at IS NULL"
  end

  def down
    remove_column :users, :terms_accepted_at
  end
end
