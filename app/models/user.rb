class User < ApplicationRecord
  # available_days: substituida por preferred_training_days. last_strava_sync_at:
  # substituida por strava_integrations.last_sync_at. Coluna fica no banco ate
  # o deploy com ignored_columns estar no ar; remove_column vem depois.
  self.ignored_columns += %w[available_days last_strava_sync_at]

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

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
  has_many :admin_actions, class_name: "AdminAuditLog", foreign_key: "admin_id", dependent: :destroy
  has_many :received_admin_actions, class_name: "AdminAuditLog", foreign_key: "target_user_id", dependent: :destroy

  # Pisos/tetos ancorados em recorde mundial -- fora disso e impossivel, nao
  # so "otimista", e alimentaria a IA com premissa falsa.
  MIN_5K_TIME_SECONDS = 720
  MAX_5K_TIME_SECONDS = 7200
  MIN_10K_TIME_SECONDS = 1500
  MAX_10K_TIME_SECONDS = 14400
  MIN_HALF_MARATHON_TIME_SECONDS = 3300
  MAX_HALF_MARATHON_TIME_SECONDS = 21600
  MAX_WEEKLY_MILEAGE_KM = 300
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  AVATAR_MAX_SIZE = 5.megabytes

  # Minimo 18 anos: consentimento parental (LGPD Art. 14) para menores nao
  # esta implementado.
  validates :age, numericality: { greater_than_or_equal_to: 18, less_than_or_equal_to: 120, allow_nil: true, message: "deve ser maior de idade (18 anos) -- o Runify ainda não oferece o fluxo de consentimento para menores" }
  validates :weight, numericality: { greater_than: 30, less_than_or_equal_to: 300, allow_nil: true, message: "deve estar entre 30kg e 300kg" }
  validates :height, numericality: { greater_than: 100, less_than_or_equal_to: 250, allow_nil: true, message: "deve estar entre 100cm e 250cm" }
  validates :goal, length: { maximum: 500, allow_nil: true, message: "não pode exceder 500 caracteres" }
  validates :avatar, content_type: AVATAR_CONTENT_TYPES, size: { less_than_or_equal_to: AVATAR_MAX_SIZE }

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

  # Virtual: o banco guarda terms_accepted_at (timestamp), nao um boolean --
  # e a evidencia que importa se precisar provar consentimento.
  attr_accessor :terms_accepted
  # AcceptanceValidator tem allow_nil: true por padrao -- sem os dois em
  # false, um POST sem o parametro passa sem nenhum consentimento.
  validates :terms_accepted, acceptance: {
    allow_nil: false,
    allow_blank: false,
    message: "é obrigatório aceitar a Política de Privacidade e os Termos de Uso"
  }, on: :create
  before_create :record_terms_acceptance

  validates :running_experience, inclusion: {
    in: %w[beginner intermediate advanced],
    allow_nil: true
  }
  validates :running_experience_years, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 80,
    allow_nil: true
  }

  # Indice unico de verdade no banco tambem (ver AddOmniauthToUsers) --
  # mesma logica ja aplicada ao athlete_id do Strava depois do bug de 2026-08-18.
  validates :uid, uniqueness: { scope: :provider }, allow_nil: true

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
    ((Date.current - birth_date).to_i / 365)
  end

  def avatar_url
    if avatar.attached?
      Rails.application.routes.url_helpers.rails_blob_path(avatar, only_path: true)
    else
      initials_avatar_data_uri
    end
  end

  def primary_squad_member
    squad_members.order(level: :desc, experience_points: :desc).first
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
    recent = activities.runs.where("start_date > ?", 30.days.ago)
                       .where.not(average_speed: nil)
                       .limit(10)

    return nil if recent.empty?

    avg_speed = recent.average(:average_speed).to_f
    return nil if avg_speed.zero?

    (1000.0 / (avg_speed * 60)).round(2)
  end

  private

  def record_terms_acceptance
    self.terms_accepted_at = Time.current
  end

  # Sem foto: iniciais geradas aqui mesmo, sem depender de terceiro (ver
  # docs/security.md). Sanitizado pra so letra/numero antes de virar SVG --
  # username de cadastro e texto livre do usuario.
  def initials_avatar_data_uri
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
        <rect width="200" height="200" fill="#14b8a6" />
        <text x="50%" y="50%" dy=".35em" text-anchor="middle" font-family="sans-serif" font-size="80" fill="#fff">#{avatar_initials}</text>
      </svg>
    SVG

    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end

  def avatar_initials
    source = username.presence || email.to_s.split("@").first.to_s
    source.scan(/[a-zA-Z0-9]/).first(2).join.upcase.presence || "?"
  end
end
