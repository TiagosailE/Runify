class Activity < ApplicationRecord
  belongs_to :user

  def distance_km
    return 0 unless distance
    (distance / 1000.0).round(2)
  end

  def duration_formatted
    return '0:00' unless duration
    hours = duration / 3600
    minutes = (duration % 3600) / 60
    seconds = duration % 60
    
    if hours > 0
      format('%d:%02d:%02d', hours, minutes, seconds)
    else
      format('%d:%02d', minutes, seconds)
    end
  end

  def pace_per_km
    return '--:--' unless distance && moving_time && distance > 0
    pace_seconds = (moving_time / (distance / 1000.0)).to_i
    minutes = pace_seconds / 60
    seconds = pace_seconds % 60
    format("%d:%02d'", minutes, seconds)
  end

  def formatted_date
    start_date.strftime('%d/%m/%Y')
  end
end