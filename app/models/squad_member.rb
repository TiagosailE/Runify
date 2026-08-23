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
      "bronze_runner"
    when 20..39
      "steel_athlete"
    when 40..59
      "golden_marathon"
    when 60..79
      "platinum_elite"
    when 80..99
      "ethereal_legend"
    else
      "mythic_immortal"
    end
  end

  TIER_DATA = {
    "bronze_runner"   => { name: "Bronze Runner",   color: "#8B4513", icon: "fa-shoe-prints" },
    "steel_athlete"   => { name: "Steel Athlete",   color: "#C0C0C0", icon: "fa-running" },
    "golden_marathon" => { name: "Golden Marathon", color: "#FFD700", icon: "fa-bolt" },
    "platinum_elite"  => { name: "Platinum Elite",  color: "#00FFFF", icon: "fa-crown" },
    "ethereal_legend" => { name: "Ethereal Legend", color: "#9D4EDD", icon: "fa-star" },
    "mythic_immortal" => { name: "Mythic Immortal", color: "#FF006E", icon: "fa-fire" }
  }.freeze

  def border_color
    tier_data[:color]
  end

  def tier_icon
    tier_data[:icon]
  end

  def tier_data
    TIER_DATA[border_tier]
  end

  def has_cardinal_points?
    level >= 60
  end

  def has_orbit_particles?
    level >= 80
  end

  def rank_title
    case level
    when 1..19 then "Iniciante"
    when 20..39 then "Corredor"
    when 40..59 then "Maratonista"
    when 60..79 then "Elite"
    when 80..99 then "Lenda"
    else "Imortal"
    end
  end

  def rank_color_class
    tier = border_tier

    case tier
    when "bronze_runner" then "text-amber-700"
    when "steel_athlete" then "text-gray-300"
    when "golden_marathon" then "text-yellow-400"
    when "platinum_elite" then "text-cyan-400"
    when "ethereal_legend" then "text-purple-400"
    when "mythic_immortal" then "text-pink-500"
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
