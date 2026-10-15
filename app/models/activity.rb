class Activity < ApplicationRecord
  SOURCES = %w[strava manual].freeze
  RUN_SPORT_TYPES = %w[Run TrailRun VirtualRun].freeze
  WALK_SPORT_TYPES = %w[Walk].freeze
  MANUAL_SPORT_TYPES = { "Run" => "Corrida", "Walk" => "Caminhada" }.freeze
  MAX_INCLINE_PERCENT = 15

  # Vai junto do histórico no prompt da IA quando há esteira ou caminhada.
  # Base: Jones & Doust (1996), 1% de inclinação iguala o custo energético da
  # rua só em ritmo mais forte (10,5 a 18 km/h); abaixo disso a diferença
  # some. A distância da esteira vem da rotação da correia, sem GPS.
  AI_CONTEXT_NOTE = "Como interpretar: na esteira a distância é estimada pela máquina e pode errar " \
                    "alguns por cento. Em ritmo de corredor amador o esforço por km na esteira plana " \
                    "é parecido com o da rua; cada ponto de inclinação deixa o treino mais pesado " \
                    "que o ritmo sugere. Caminhada conta como volume de atividade, mas não é " \
                    "referência de ritmo de corrida.".freeze

  belongs_to :user

  scope :runs, -> { where(sport_type: RUN_SPORT_TYPES) }
  scope :runs_and_walks, -> { where(sport_type: RUN_SPORT_TYPES + WALK_SPORT_TYPES) }

  validates :distance, numericality: { greater_than: 0, message: "deve ser maior que zero" }
  validates :duration, numericality: { greater_than: 0, only_integer: true, message: "deve ser maior que zero" }
  validates :start_date, presence: { message: "é obrigatória" }
  validates :sport_type, presence: { message: "é obrigatório" }
  validates :source, inclusion: { in: SOURCES }
  validates :incline_percent,
    numericality: { in: 0..MAX_INCLINE_PERCENT, message: "deve ficar entre 0 e #{MAX_INCLINE_PERCENT}%" },
    allow_nil: true

  def distance_km
    return 0 unless distance
    (distance / 1000.0).round(2)
  end

  def duration_formatted
    return "0:00" unless duration
    hours = duration / 3600
    minutes = (duration % 3600) / 60
    seconds = duration % 60

    if hours > 0
      format("%d:%02d:%02d", hours, minutes, seconds)
    else
      format("%d:%02d", minutes, seconds)
    end
  end

  def pace_per_km
    return "--:--" unless distance && moving_time && distance > 0
    pace_seconds = (moving_time / (distance / 1000.0)).to_i
    minutes = pace_seconds / 60
    seconds = pace_seconds % 60
    format("%d:%02d'", minutes, seconds)
  end

  def formatted_date
    start_date.strftime("%d/%m/%Y")
  end

  def run?
    RUN_SPORT_TYPES.include?(sport_type)
  end

  def walk?
    WALK_SPORT_TYPES.include?(sport_type)
  end

  def context_label
    label = walk? ? "caminhada" : "corrida"
    return label unless treadmill?

    label += " na esteira"
    return label if incline_percent.nil?

    incline = ActiveSupport::NumberHelper.number_to_rounded(incline_percent, precision: 1, strip_insignificant_zeros: true)
    "#{label}, inclinação #{incline}%"
  end
end
