class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.order(created_at: :desc)
    @unread_count = current_user.notifications.unread.count
  end

  def mark_as_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read!
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: notifications_path) }
      format.json { render json: { success: true } }
    end
  end

  def mark_all_as_read
    current_user.notifications.unread.update_all(read: true)
    
    respond_to do |format|
      format.html { redirect_to notifications_path, notice: 'Todas as notificações foram marcadas como lidas' }
      format.json { render json: { success: true } }
    end
  end
end