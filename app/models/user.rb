class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :strava_integration, dependent: :destroy
  has_many :activities, dependent: :destroy

  def strava_connected?
    strava_integration.present? && strava_integration.active?
  end

  def recent_activities(limit = 2)
    activities.order(start_date: :desc).limit(limit)
  end
end