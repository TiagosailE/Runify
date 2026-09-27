class TrainingPlan < ApplicationRecord
  belongs_to :user
  has_many :workouts, dependent: :destroy

  validates :status, inclusion: { in: %w[active completed cancelled] }

  scope :active, -> { where(status: "active") }

  # A semana 1 e a semana calendario (segunda a domingo) de start_date, mesmo
  # que o plano tenha sido gerado no meio dela.
  def current_week
    return 0 unless start_date
    ((Date.current - start_date.beginning_of_week(:monday)).to_i / 7) + 1
  end

  def workouts_for_week(week_number)
    workouts.where(week_number: week_number).order(:day_of_week)
  end

  def current_week_workouts
    workouts_for_week(current_week)
  end

  def completed?
    status == "completed"
  end

  def active?
    status == "active"
  end
end
