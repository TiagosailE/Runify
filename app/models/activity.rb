class Activity < ApplicationRecord
  SOURCES = %w[strava manual].freeze

  belongs_to :user

  validates :distance, numericality: { greater_than: 0, message: "deve ser maior que zero" }
  validates :duration, numericality: { greater_than: 0, only_integer: true, message: "deve ser maior que zero" }
  validates :start_date, presence: { message: "é obrigatória" }
  validates :sport_type, presence: { message: "é obrigatório" }
  validates :source, inclusion: { in: SOURCES }

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
end
