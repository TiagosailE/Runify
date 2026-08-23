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
  has_many :owned_squads, class_name: "Squad", foreign_key: "owner_id", dependent: :destroy
  has_many :user_achievements, dependent: :destroy
  has_many :achievements, through: :user_achievements

  # Pisos ancorados em recorde mundial (5km 12:35, 10km 26:11, meia 56:42) e
  # tetos no limite do que ainda e uma prova concluida. Dado fora disso nao e
  # "otimista", e impossivel -- e alimenta a IA com premissa falsa. O min/max
  # do HTML no formulario nao vale nada: contorna-se pelo DevTools.
  MIN_5K_TIME_SECONDS = 720
  MAX_5K_TIME_SECONDS = 7200
  MIN_10K_TIME_SECONDS = 1500
  MAX_10K_TIME_SECONDS = 14400
  MIN_HALF_MARATHON_TIME_SECONDS = 3300
  MAX_HALF_MARATHON_TIME_SECONDS = 21600
  MAX_WEEKLY_MILEAGE_KM = 300

  validates :age, numericality: { greater_than_or_equal_to: 12, less_than_or_equal_to: 120, allow_nil: true, message: "deve estar entre 12 e 120 anos" }
  validates :weight, numericality: { greater_than: 30, less_than_or_equal_to: 300, allow_nil: true, message: "deve estar entre 30kg e 300kg" }
  validates :height, numericality: { greater_than: 100, less_than_or_equal_to: 250, allow_nil: true, message: "deve estar entre 100cm e 250cm" }
  validates :goal, length: { maximum: 500, allow_nil: true, message: "não pode exceder 500 caracteres" }

  validates :best_5k_time, numericality: {
    greater_than_or_equal_to: MIN_5K_TIME_SECONDS,
    less_than_or_equal_to: MAX_5K_TIME_SECONDS,
    allow_nil: true,
    message: "deve estar entre 12 minutos (perto do recorde mundial) e 2 horas"
  }
  validates :best_10k_time, numericality: {
    greater_than_or_equal_to: MIN_10K_TIME_SECONDS,
    less_than_or_equal_to: MAX_10K_TIME_SECONDS,
    allow_nil: true,
    message: "deve estar entre 25 minutos (perto do recorde mundial) e 4 horas"
  }
  validates :best_half_marathon_time, numericality: {
    greater_than_or_equal_to: MIN_HALF_MARATHON_TIME_SECONDS,
    less_than_or_equal_to: MAX_HALF_MARATHON_TIME_SECONDS,
    allow_nil: true,
    message: "deve estar entre 55 minutos (perto do recorde mundial) e 6 horas"
  }
  validates :weekly_mileage, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: MAX_WEEKLY_MILEAGE_KM,
    allow_nil: true,
    message: "deve estar entre 0 e #{MAX_WEEKLY_MILEAGE_KM}km por semana"
  }

  validates :running_experience, inclusion: {
    in: %w[beginner intermediate advanced],
    allow_nil: true
  }
  validates :running_experience_years, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 80,
    allow_nil: true
  }

  def strava_connected?
    strava_integration.present? && strava_integration.active?
  end

  def recent_activities(limit = 2)
    activities.order(start_date: :desc).limit(limit)
  end

  def active_training_plan
    training_plans.where(status: "active").order(created_at: :desc).first
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
    primary_squad_member&.border_color || "border-gray-400"
  end

  def notifications_enabled?
    notifications_enabled == true
  end

  def runner_level
    return "beginner" unless running_experience.present?

    case running_experience
    when "beginner"
      "Iniciante"
    when "intermediate"
      "Intermediário"
    when "advanced"
      "Avançado"
    end
  end

  def estimated_vo2_max
    return nil unless best_10k_time.present? && age.present?

    time_in_minutes = best_10k_time / 60.0
    vo2 = (483 / time_in_minutes) + 3.5

    age_factor = 1 - ((age - 25) * 0.01) if age > 25
    vo2 * (age_factor || 1)
  end

  def average_recent_pace
    recent = activities.where("start_date > ?", 30.days.ago)
                       .where.not(average_speed: nil)
                       .limit(10)

    return nil if recent.empty?

    avg_speed = recent.average(:average_speed).to_f
    return nil if avg_speed.zero?

    (1000.0 / (avg_speed * 60)).round(2)
  end
end
