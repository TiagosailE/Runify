class Workout < ApplicationRecord
  FORMATS = %w[continuous run_walk].freeze

  belongs_to :training_plan

  validates :status, inclusion: { in: %w[pending completed skipped] }
  validates :workout_format, inclusion: { in: FORMATS }
  validates :week_number, numericality: { greater_than: 0, only_integer: true }
  validates :day_of_week, numericality: { greater_than: 0, less_than_or_equal_to: 7, only_integer: true }
  # Ultima linha de defesa antes do banco: nem IA nem ajuste automatico
  # conseguem gravar um treino com numero impossivel. Distancia e opcional
  # porque em caminhada/corrida ela e consequencia, nao prescricao.
  validates :distance, numericality: {
    greater_than: 0,
    less_than_or_equal_to: 100,
    allow_nil: true
  }
  validates :duration, numericality: {
    greater_than: 0,
    less_than_or_equal_to: 8.hours.to_i,
    only_integer: true,
    allow_nil: true
  }
  validate :distance_required_for_continuous

  scope :pending, -> { where(status: "pending") }
  scope :completed, -> { where(status: "completed") }
  scope :for_date, ->(date) { where(scheduled_date: date) }

  def run_walk?
    workout_format == "run_walk"
  end

  # Passos de caminhada/corrida, ex: [{"activity" => "run", "seconds" => 60,
  # "repeat" => 8}]. Vazio em treino continuo.
  def steps
    Array(workout_details&.dig("steps"))
  end

  def distance_km
    return 0 unless distance
    distance.round(2)
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

  def completed?
    status == "completed"
  end

  def pending?
    status == "pending"
  end

  def mark_as_completed!
    update(status: "completed")
  end

  def mark_as_skipped!
    update(status: "skipped")
  end

  private

  def distance_required_for_continuous
    return if run_walk?
    return if distance.present?

    errors.add(:distance, "é obrigatória em treino de corrida contínua")
  end
end
