class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one_attached :avatar
  has_one :strava_integration, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :training_plans, dependent: :destroy

  def strava_connected?
    strava_integration.present? && strava_integration.active?
  end

  def recent_activities(limit = 2)
    activities.order(start_date: :desc).limit(limit)
  end

  def active_training_plan
    training_plans.active.order(created_at: :desc).first
  end

  def has_active_plan?
    active_training_plan.present?
  end

  def age
    return nil unless birth_date
    ((Date.today - birth_date).to_i / 365)
  end

  def avatar_url
    if avatar.attached?
      Rails.application.routes.url_helpers.rails_blob_path(avatar, only_path: true)
    else
      "https://ui-avatars.com/api/?name=#{username || email}&background=14b8a6&color=fff&size=200"
    end
  end
end