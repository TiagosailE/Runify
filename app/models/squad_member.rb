class SquadMember < ApplicationRecord
  belongs_to :squad
  belongs_to :user

  def add_xp(amount)
    self.experience_points += amount
    check_level_up
    save
  end

  def xp_for_next_level
    level * 100 + 50
  end

  def xp_progress_percentage
    ((experience_points.to_f / xp_for_next_level) * 100).round
  end

  def border_color
    case (level / 10)
    when 0
      'border-gray-400'
    when 1
      'border-green-500'
    when 2
      'border-blue-500'
    when 3
      'border-purple-500'
    when 4
      'border-yellow-500'
    when 5..9
      'border-red-500'
    else
      'border-gradient-to-r from-yellow-400 via-red-500 to-pink-500'
    end
  end

  def rank_title
    case level
    when 1..9 then 'Iniciante'
    when 10..19 then 'Corredor'
    when 20..29 then 'Atleta'
    when 30..39 then 'Veterano'
    when 40..49 then 'Elite'
    when 50..99 then 'Lenda'
    else 'Imortal'
    end
  end

  private

  def check_level_up
    while experience_points >= xp_for_next_level
      self.experience_points -= xp_for_next_level
      self.level += 1
    end
  end
end