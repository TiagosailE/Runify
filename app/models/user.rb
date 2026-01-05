class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one_attached :avatar
  has_one :strava_integration, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :training_plans, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :squad_members, dependent: :destroy
  has_many :squads, through: :squad_members
  has_many :owned_squads, class_name: 'Squad', foreign_key: 'owner_id', dependent: :destroy
  has_many :user_achievements, dependent: :destroy
  has_many :achievements, through: :user_achievements

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

  def primary_squad_member
    squad_members.order(experience_points: :desc).first
  end

  def level
    primary_squad_member&.level || 1
  end

  def experience_points
    primary_squad_member&.experience_points || 0
  end

  def border_color
    primary_squad_member&.border_color || 'border-gray-400'
  end
end