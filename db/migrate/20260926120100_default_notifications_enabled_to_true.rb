class DefaultNotificationsEnabledToTrue < ActiveRecord::Migration[8.1]
  # So o default: quem ja existe mantem a escolha que tem hoje.
  def change
    change_column_default :users, :notifications_enabled, from: false, to: true
  end
end
