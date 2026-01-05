class Notification < ApplicationRecord
  belongs_to :user

  validates :notification_type, inclusion: { 
    in: %w[workout_reminder sync_reminder congratulations weekly_summary] 
  }

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc).limit(10) }

  def mark_as_read!
    update(read: true)
  end
end