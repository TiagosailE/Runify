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
    when 1..19
      'bronze_runner'
    when 20..39
      'steel_athlete'
    when 40..59
      'golden_marathon'
    when 60..79
      'platinum_elite'
    when 80..99
      'ethereal_legend'
    else
      'mythic_immortal'
    end
  end

  def border_color
    tier_data[:color]
  end

  def border_glow
    tier_data[:box_shadow]
  end

  def tier_icon
    icons = {
      'bronze_runner' => 'fa-shoe-prints',
      'steel_athlete' => 'fa-running',
      'golden_marathon' => 'fa-bolt',
      'platinum_elite' => 'fa-crown',
      'ethereal_legend' => 'fa-star',
      'mythic_immortal' => 'fa-fire'
    }
    icons[border_tier]
  end

  def tier_data
    tiers = {
      'bronze_runner' => {
        name: 'Bronze Runner',
        color: '#8B4513',
        border: '4px solid #8B4513',
        box_shadow: '0 0 0 2px #654321, inset 0 2px 4px rgba(0,0,0,0.5), 0 4px 8px rgba(139,69,19,0.4)',
        background: 'repeating-linear-gradient(90deg, rgba(139,69,19,0.1) 0px, rgba(101,67,33,0.1) 2px, rgba(139,69,19,0.1) 4px)',
        animation: nil
      },
      'steel_athlete' => {
        name: 'Steel Athlete',
        color: '#C0C0C0',
        border: '3px solid #C0C0C0',
        box_shadow: '0 0 0 1px #A8A8A8, 0 0 0 4px #E0E0E0, 0 0 20px rgba(100,149,237,0.3), inset 0 2px 4px rgba(255,255,255,0.5), 0 4px 12px rgba(192,192,192,0.6)',
        background: 'linear-gradient(135deg, rgba(192,192,192,0.1) 0%, rgba(224,224,224,0.1) 50%, rgba(192,192,192,0.1) 100%)',
        animation: nil
      },
      'golden_marathon' => {
        name: 'Golden Marathon',
        color: '#FFD700',
        border: '4px solid #FFD700',
        box_shadow: '0 0 0 2px #FFA500, 0 0 0 5px #FFD700, 0 0 30px rgba(255,215,0,0.6), 0 0 50px rgba(255,165,0,0.4), inset 0 0 20px rgba(255,255,255,0.3), 0 6px 20px rgba(255,215,0,0.5)',
        background: 'radial-gradient(circle at 30% 30%, rgba(255,255,255,0.3) 0%, rgba(255,215,0,0.1) 50%, transparent 100%)',
        animation: 'pulse-gold 3s ease-in-out infinite'
      },
      'platinum_elite' => {
        name: 'Platinum Elite',
        color: '#00FFFF',
        border: '5px solid transparent',
        box_shadow: '0 0 30px rgba(0,255,255,0.5), 0 0 60px rgba(14,165,233,0.3), inset 0 0 30px rgba(0,255,255,0.2), 0 8px 32px rgba(0,255,255,0.4)',
        background_image: 'linear-gradient(#1a1a1a, #1a1a1a), linear-gradient(135deg, #00ffff, #0ff, #00ffff, #0ea5e9, #00ffff)',
        animation: 'pulse-cyan 2s ease-in-out infinite'
      },
      'ethereal_legend' => {
        name: 'Ethereal Legend',
        color: '#9D4EDD',
        border: '6px solid transparent',
        box_shadow: '0 0 40px rgba(157,78,221,0.8), 0 0 80px rgba(255,0,110,0.6), 0 0 120px rgba(157,78,221,0.4), inset 0 0 40px rgba(255,190,11,0.3), 0 10px 40px rgba(157,78,221,0.6)',
        background_image: 'linear-gradient(#1a1a1a, #1a1a1a), linear-gradient(270deg, #9D4EDD, #FF006E, #FFBE0B, #FF006E, #9D4EDD)',
        animation: 'ethereal 4s ease-in-out infinite'
      },
      'mythic_immortal' => {
        name: 'Mythic Immortal',
        color: '#FF006E',
        border: '8px solid transparent',
        box_shadow: '0 0 50px rgba(255,0,110,1), 0 0 100px rgba(131,56,236,0.8), 0 0 150px rgba(58,134,255,0.6), inset 0 0 50px rgba(251,86,7,0.4), 0 0 200px rgba(255,190,11,0.3), 0 12px 50px rgba(255,0,110,0.8)',
        background_image: 'linear-gradient(#1a1a1a, #1a1a1a), linear-gradient(45deg, #FF006E, #8338EC, #3A86FF, #FB5607, #FFBE0B, #FF006E)',
        animation: 'mythic 6s linear infinite'
      }
    }
    tiers[border_tier]
  end

  def border_style
    data = tier_data
    style = []
    
    style << "border: #{data[:border]};"
    style << "box-shadow: #{data[:box_shadow]};"
    
    if data[:background_image]
      style << "background-image: #{data[:background_image]};"
      style << "background-origin: border-box;"
      style << "background-clip: padding-box, border-box;"
    elsif data[:background]
      style << "background: #{data[:background]};"
    end
    
    style.join(' ')
  end

  def has_cardinal_points?
    level >= 60
  end

  def has_orbit_particles?
    level >= 80
  end

  def rank_title
    case level
    when 1..19 then 'Iniciante'
    when 20..39 then 'Corredor'
    when 40..59 then 'Maratonista'
    when 60..79 then 'Elite'
    when 80..99 then 'Lenda'
    else 'Imortal'
    end
  end

  def rank_color_class
    tier = border_tier
    
    case tier
    when 'bronze_runner' then 'text-amber-700'
    when 'steel_athlete' then 'text-gray-300'
    when 'golden_marathon' then 'text-yellow-400'
    when 'platinum_elite' then 'text-cyan-400'
    when 'ethereal_legend' then 'text-purple-400'
    when 'mythic_immortal' then 'text-pink-500'
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