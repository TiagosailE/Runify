class AddTermsAcceptedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :terms_accepted_at, :datetime

    # Contas que ja existiam antes do checkbox de consentimento existir --
    # nao tem como coletar aceite retroativo de verdade, entao a data de
    # criacao da conta fica registrada como marco de referencia (todas sao
    # contas de teste/demo, pre-lancamento, nenhum usuario real ainda).
    execute "UPDATE users SET terms_accepted_at = created_at WHERE terms_accepted_at IS NULL"
  end

  def down
    remove_column :users, :terms_accepted_at
  end
end
