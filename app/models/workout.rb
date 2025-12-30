class Workout < ApplicationRecord
  belongs_to :training_plan

  validates :status, inclusion: { in: %w[pending completed skipped] }

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :for_date, ->(date) { where(scheduled_date: date) }

  def distance_km
    return 0 unless distance
    distance.round(2)
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

  def completed?
    status == 'completed'
  end

  def pending?
    status == 'pending'
  end

  def mark_as_completed!
    update(status: 'completed')
  end

  def mark_as_skipped!
    update(status: 'skipped')
  end
end