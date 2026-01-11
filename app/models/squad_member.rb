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

  def border_tier
    case level
    when 1..9
      'iron'
    when 10..19
      'bronze'
    when 20..29
      'silver'
    when 30..39
      'gold'
    when 40..49
      'platinum'
    when 50..69
      'diamond'
    when 70..89
      'master'
    when 90..99
      'grandmaster'
    else
      'challenger'
    end
  end

  def border_color
    tier = border_tier
    
    case tier
    when 'iron' then '#6B7280'
    when 'bronze' then '#92400E'
    when 'silver' then '#D1D5DB'
    when 'gold' then '#F59E0B'
    when 'platinum' then '#06B6D4'
    when 'diamond' then '#8B5CF6'
    when 'master' then '#EC4899'
    when 'grandmaster' then '#EF4444'
    when 'challenger' then '#FBBF24'
    end
  end

  def border_glow
    tier = border_tier
    
    case tier
    when 'iron' then '0 0 15px rgba(107, 114, 128, 0.5)'
    when 'bronze' then '0 0 20px rgba(146, 64, 14, 0.6)'
    when 'silver' then '0 0 25px rgba(209, 213, 219, 0.7)'
    when 'gold' then '0 0 30px rgba(245, 158, 11, 0.8)'
    when 'platinum' then '0 0 35px rgba(6, 182, 212, 0.9)'
    when 'diamond' then '0 0 40px rgba(139, 92, 246, 1)'
    when 'master' then '0 0 45px rgba(236, 72, 153, 1)'
    when 'grandmaster' then '0 0 50px rgba(239, 68, 68, 1)'
    when 'challenger' then '0 0 60px rgba(251, 191, 36, 1), 0 0 80px rgba(239, 68, 68, 0.6)'
    end
  end

  def tier_icon
    tier_icons = {
      'iron' => 'fa-shoe-prints',
      'bronze' => 'fa-running',
      'silver' => 'fa-bolt',
      'gold' => 'fa-trophy',
      'platinum' => 'fa-crown',
      'diamond' => 'fa-gem',
      'master' => 'fa-star',
      'grandmaster' => 'fa-fire',
      'challenger' => 'fa-rocket'
    }
    tier_icons[border_tier]
  end

  def rank_title
    case level
    when 1..9 then 'Iniciante'
    when 10..19 then 'Corredor'
    when 20..29 then 'Atleta'
    when 30..39 then 'Veterano'
    when 40..49 then 'Elite'
    when 50..69 then 'Lenda'
    when 70..89 then 'Mestre'
    when 90..99 then 'Grão-Mestre'
    else 'Desafiante'
    end
  end

  def rank_color_class
    tier = border_tier
    
    case tier
    when 'iron' then 'text-gray-400'
    when 'bronze' then 'text-amber-700'
    when 'silver' then 'text-gray-300'
    when 'gold' then 'text-yellow-400'
    when 'platinum' then 'text-cyan-400'
    when 'diamond' then 'text-purple-400'
    when 'master' then 'text-pink-400'
    when 'grandmaster' then 'text-red-400'
    when 'challenger' then 'text-yellow-400'
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