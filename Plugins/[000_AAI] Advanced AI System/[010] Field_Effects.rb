#===============================================================================
# Advanced AI System - Field Effects
# Weather, Terrain, Trick Room, Gravity Awareness
#===============================================================================

module AdvancedAI
  module FieldEffects
    # Main Function: Calculates Field Effect Bonus
    def self.field_effect_bonus(battle, move, user, target, skill_level = 100)
      return 0 unless skill_level >= 70
      
      bonus = 0
      bonus += weather_bonus(battle, move, user, target)
      bonus += terrain_bonus(battle, move, user, target)
      bonus += trick_room_bonus(battle, move, user, target)
      bonus += gravity_bonus(battle, move, user, target)
      bonus += room_bonus(battle, move, user, target)
      
      bonus
    end
    
    # Weather Bonus
    def self.weather_bonus(battle, move, user, target)
      return 0 unless battle.field.weather
      
      bonus = 0
      weather = battle.field.weather
      
      case weather
      when :Sun, :HarshSun
        if move.type == :FIRE
          bonus += 30  # Fire moves x1.5
        elsif move.type == :WATER
          bonus -= 30  # Water moves x0.5
        end
        
        # Weather Ball, Growth
        bonus += 20 if move.id == :WEATHERBALL
        bonus += 15 if move.id == :GROWTH
        
      when :Rain, :HeavyRain
        if move.type == :WATER
          bonus += 30  # Water moves x1.5
        elsif move.type == :FIRE
          bonus -= 30  # Fire moves x0.5
        end
        
        bonus += 25 if move.id == :THUNDER || move.id == :HURRICANE  # 100% accuracy
        bonus += 20 if move.id == :WEATHERBALL
        
      when :Sandstorm
        bonus += 20 if move.id == :WEATHERBALL
        bonus += 15 if move.id == :SHOREUP  # Heals more
        
        # Rock types get SpDef boost
        if target && !target.pbHasType?(:ROCK) && !target.pbHasType?(:STEEL) && !target.pbHasType?(:GROUND)
          bonus += 10  # Target takes residual damage
        end
        
      when :Hail, :Snow
        bonus += 30 if move.id == :BLIZZARD  # 100% accuracy
        bonus += 20 if move.id == :WEATHERBALL
        bonus += 25 if move.id == :AURORAVEIL  # Aurora Veil only in Hail/Snow
        
        # Ice types immune to Hail damage
        bonus += 5 if user.pbHasType?(:ICE)
      end
      
      # Ability Synergies
      ability = user.ability_id
      case ability
      when :SWIFTSWIM
        bonus += 20 if weather == :Rain || weather == :HeavyRain
      when :CHLOROPHYLL
        bonus += 20 if weather == :Sun || weather == :HarshSun
      when :SANDRUSH
        bonus += 20 if weather == :Sandstorm
      when :SLUSHRUSH
        bonus += 20 if weather == :Hail || weather == :Snow
      end
      
      bonus
    end
    
    # Terrain Bonus
    def self.terrain_bonus(battle, move, user, target)
      return 0 unless battle.field.terrain
      
      bonus = 0
      terrain = battle.field.terrain
      
      case terrain
      when :Electric
        if move.type == :ELECTRIC && user.affectedByTerrain?
          bonus += 25  # x1.3 power
        end
        bonus -= 40 if move.id == :SLEEPPOWDER || move.id == :SPORE  # Can't sleep
        
      when :Grassy
        if move.type == :GRASS && user.affectedByTerrain?
          bonus += 25  # x1.3 power
        end
        bonus -= 20 if move.id == :EARTHQUAKE || move.id == :MAGNITUDE  # x0.5 power
        bonus += 15 if move.id == :GIGADRAIN || move.id == :DRAINPUNCH  # Better healing
        
      when :Psychic
        if move.type == :PSYCHIC && user.affectedByTerrain?
          bonus += 25  # x1.3 power
        end
        prio = move.respond_to?(:priority) ? move.priority : (move.respond_to?(:move) ? move.move.priority : 0)
        bonus -= 40 if prio > 0  # Priority blocked
        
      when :Misty
        if move.type == :DRAGON
          bonus -= 30  # x0.5 power
        end
        bonus -= 40 if move.statusMove? && target && target.affectedByTerrain?  # Status blocked
      end
      
      # Ability Synergies
      ability = user.ability_id
      bonus += 20 if ability == :SURGESURFER && terrain == :Electric
      
      bonus
    end
    
    # Trick Room Bonus
    def self.trick_room_bonus(battle, move, user, target)
      return 0 unless battle.field.effects[PBEffects::TrickRoom] > 0
      
      bonus = 0
      
      # If Trick Room active, prefer slow Pokemon
      if user.pbSpeed < 50
        bonus += 20  # Slow Pokemon benefits
      elsif user.pbSpeed > 120
        bonus -= 20  # Fast Pokemon penalized
      end
      
      # Priority Moves are stronger in Trick Room
      prio = move.respond_to?(:priority) ? move.priority : (move.respond_to?(:move) ? move.move.priority : 0)
      bonus += 15 if prio > 0
      
      bonus
    end
    
    # Gravity Bonus
    def self.gravity_bonus(battle, move, user, target)
      return 0 unless battle.field.effects[PBEffects::Gravity] > 0
      
      bonus = 0
      
      # OHKO moves 100% accuracy
      if [:GUILLOTINE, :FISSURE, :SHEERCOLD, :HORNDRILL].include?(move.id)
        bonus += 40
      end
      
      # Ground moves hit Flying/Levitate
      if move.type == :GROUND && target
        bonus += 30 if target.pbHasType?(:FLYING) || target.ability_id == :LEVITATE
      end
      
      bonus
    end
    
    # Room Effects (Magic Room, Wonder Room)
    def self.room_bonus(battle, move, user, target)
      bonus = 0
      
      # Magic Room (items disabled)
      if battle.field.effects[PBEffects::MagicRoom] > 0
        # Item-dependent Moves are weaker
        bonus -= 20 if move.id == :FLING || move.id == :NATURALGIFT
      end
      
      # Wonder Room (Def/SpDef swapped)
      if battle.field.effects[PBEffects::WonderRoom] > 0
        if move.physicalMove? && target && target.spdef > target.defense
          bonus += 15  # Physical hits SpDef now (better)
        elsif move.specialMove? && target && target.defense > target.spdef
          bonus += 15  # Special hits Def now (better)
        end
      end
      
      bonus
    end
    
    # Weather Setting Bonus
    def self.weather_setting_bonus(battle, move, user, skill_level = 100)
      return 0 unless skill_level >= 70
      
      bonus = 0
      
      # Check if Team benefits from Weather
      party = battle.pbParty(user.index)
      
      case move.id
      when :SUNNYDAY
        sun_users = party.count { |p| p && [:CHLOROPHYLL, :DROUGHT, :SOLARPOWER].include?(p.ability) }
        bonus += sun_users * 20
        
      when :RAINDANCE
        rain_users = party.count { |p| p && [:SWIFTSWIM, :DRIZZLE, :RAINDISH].include?(p.ability) }
        bonus += rain_users * 20
        
      when :SANDSTORM
        sand_users = party.count { |p| p && [:SANDRUSH, :SANDSTREAM, :SANDFORCE].include?(p.ability) }
        bonus += sand_users * 20
        
      when :HAIL, :SNOWSCAPE
        hail_users = party.count { |p| p && [:SLUSHRUSH, :SNOWWARNING, :ICEBODY].include?(p.ability) }
        bonus += hail_users * 20
      end
      
      bonus
    end
  end
end

# API-Wrapper
module AdvancedAI
  def self.field_effect_bonus(battle, move, user, target, skill_level = 100)
    FieldEffects.field_effect_bonus(battle, move, user, target, skill_level)
  end
  
  def self.weather_bonus(battle, move, user, target)
    FieldEffects.weather_bonus(battle, move, user, target)
  end
  
  def self.terrain_bonus(battle, move, user, target)
    FieldEffects.terrain_bonus(battle, move, user, target)
  end
  
  def self.trick_room_bonus(battle, move, user, target)
    FieldEffects.trick_room_bonus(battle, move, user, target)
  end
  
  def self.weather_setting_bonus(battle, move, user, skill_level = 100)
    FieldEffects.weather_setting_bonus(battle, move, user, skill_level)
  end
end

# Integration in Battle::AI
class Battle::AI
  def apply_field_effects(score, move, user, target)
    skill = @trainer&.skill || 100
    return score unless AdvancedAI.feature_enabled?(:core, skill)
    return score unless target
    
    # user and target are AIBattlers, need real battlers
    real_user = user.respond_to?(:battler) ? user.battler : user
    real_target = target.respond_to?(:battler) ? target.battler : target
    
    score += AdvancedAI.field_effect_bonus(@battle, move, real_user, real_target, skill)
    score += AdvancedAI.weather_setting_bonus(@battle, move, real_user, skill)
    
    return score
  end
end

AdvancedAI.log("Field Effects System loaded", "Field")
