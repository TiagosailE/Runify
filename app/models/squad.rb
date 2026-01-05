class Squad < ApplicationRecord
  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'
  has_many :squad_members, dependent: :destroy
  has_many :users, through: :squad_members

  validates :name, presence: true
  validates :squad_code, presence: true, uniqueness: true

  before_validation :generate_squad_code, on: :create

  def active?
    return true if challenge_end.nil?
    challenge_end >= Date.today
  end

  def leaderboard
    squad_members.order(experience_points: :desc, level: :desc)
  end

  private

  def generate_squad_code
    self.squad_code = SecureRandom.alphanumeric(8).upcase
  end
end