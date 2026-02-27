#===============================================================================
# Advanced AI System - Doubles Coordination
# Partner Synergy, Overkill Prevention, Spread Move Optimization
#===============================================================================

module AdvancedAI
  module DoublesCoordination
    # Prevents Overkill (both partners attack weak target)
    def self.prevent_overkill(battle, attacker, target, skill_level = 100)
      return 0 unless skill_level >= 50
      return 0 unless battle.pbSideSize(0) > 1  # Doubles/Triples only
      return 0 unless target
      
      partner = find_partner(battle, attacker)
      return 0 unless partner
      
      # Check if partner is also targeting this battler
      partner_targeting_same = partner_targets?(battle, partner, target)
      return 0 unless partner_targeting_same
      
      # If target is already weak
      hp_percent = target.hp.to_f / target.totalhp
      if hp_percent < 0.3
        return -40  # Switch target to avoid overkill
      elsif hp_percent < 0.5
        return -20
      end
      
      0
    end
    
    # Prevents Move Conflicts (both use same Setup/Support Move)
    def self.prevent_move_conflicts(battle, attacker, move, skill_level = 100)
      return 0 unless skill_level >= 50
      return 0 unless battle.pbSideSize(0) > 1
      
      partner = find_partner(battle, attacker)
      return 0 unless partner
      
      # Both want to set Screens
      if [:REFLECT, :LIGHTSCREEN, :AURORAVEIL].include?(move.id)
        return -60  # One is enough
      end
      
      # Both want to set Hazards
      if [:STEALTHROCK, :SPIKES, :TOXICSPIKES, :STICKYWEB].include?(move.id)
        return -50
      end
      
      # Both want to set Weather
      if [:SUNNYDAY, :RAINDANCE, :SANDSTORM, :HAIL, :SNOWSCAPE].include?(move.id)
        return -40
      end
      
      0
    end
    
    # Optimizes Spread Moves (Earthquake, etc.)
    def self.optimize_spread_moves(battle, attacker, move, skill_level = 100)
      return 0 unless skill_level >= 60
      return 0 unless battle.pbSideSize(0) > 1
      return 0 unless move.pbTarget(attacker).num_targets > 1
      
      score = 0
      partner = find_partner(battle, attacker)
      
      # Penalty if Partner is hit
      if partner && hits_partner?(move, attacker, partner)
        # Check Immunity/Resistance
        type_mod = Effectiveness.calculate(move.type, partner.types[0], partner.types[1])
        
        if Effectiveness.ineffective?(type_mod)
          score += 30  # Partner immune → very good!
        elsif Effectiveness.not_very_effective?(type_mod)
          score += 15  # Partner resists
        else
          score -= 40  # Hits Partner hard
        end
      end
      
      # Bonus if multiple enemies are hit
      enemies_hit = count_enemies_hit(battle, attacker, move)
      score += enemies_hit * 20
      
      score
    end
    
    # Coordinates Field Effects (no Weather override)
    def self.coordinate_field_effects(battle, attacker, move, skill_level = 100)
      return 0 unless skill_level >= 70
      return 0 unless battle.pbSideSize(0) > 1
      
      score = 0
      partner = find_partner(battle, attacker)
      return 0 unless partner
      
      # Weather Coordination
      if move.function_code.include?("Weather")
        # Check Partner Ability
        partner_ability = partner.ability_id
        
        if move.id == :RAINDANCE && [:SWIFTSWIM, :DRIZZLE].include?(partner_ability)
          score += 40  # Partner benefits
        elsif move.id == :SUNNYDAY && [:CHLOROPHYLL, :DROUGHT].include?(partner_ability)
          score += 40
        elsif move.id == :SANDSTORM && [:SANDRUSH, :SANDSTREAM].include?(partner_ability)
          score += 40
        elsif move.id == :HAIL && [:SLUSHRUSH, :SNOWWARNING].include?(partner_ability)
          score += 40
        end
      end
      
      # Terrain Coordination
      if move.function_code.include?("Terrain")
        partner_ability = partner.ability_id
        
        if move.id == :ELECTRICTERRAIN && [:SURGESURFER].include?(partner_ability)
          score += 35
        elsif move.id == :GRASSYTERRAIN && partner.pbHasType?(:GRASS)
          score += 25
        elsif move.id == :PSYCHICTERRAIN && [:PSYCHICSURGE].include?(partner_ability)
          score += 35
        end
      end
      
      score
    end
    
    # Protect + Setup Combo
    def self.protect_setup_combo(battle, attacker, move, skill_level = 100)
      return 0 unless skill_level >= 65
      return 0 unless battle.pbSideSize(0) > 1
      
      partner = find_partner(battle, attacker)
      return 0 unless partner
      
      # If Partner is setting up, use Protect
      if move.id == :PROTECT || move.id == :DETECT
        partner_setup = partner.moves.any? { |m| m && m.stat_up.any? }
        return 50 if partner_setup && partner.hp > partner.totalhp * 0.7
      end
      
      0
    end
    
    private
    
    def self.find_partner(battle, attacker)
      battle.allSameSideBattlers(attacker.index).find { |b| b && b != attacker && !b.fainted? }
    end
    
    def self.partner_targets?(battle, partner, target)
      # Simplified: Assumption partner attacks same target
      # In real implementation one would track AI decisions
      return false
    end
    
    def self.hits_partner?(move, attacker, partner)
      targets = move.pbTarget(attacker)
      # In v21.1, spread moves that hit partners include AllOtherPokemon, AllFoesAndAllies, etc.
      # We check if num_targets > 1 and it's NOT just hitting foes.
      return targets.num_targets > 1 && ![:AllNearFoes, :AllFoes, :RandomFoe].include?(targets.id)
    end
    
    def self.count_enemies_hit(battle, attacker, move)
      battle.allOtherSideBattlers(attacker.index).count { |b| b && !b.fainted? }
    end
  end
end

# API-Wrapper
module AdvancedAI
  def self.prevent_overkill(battle, attacker, target, skill_level = 100)
    DoublesCoordination.prevent_overkill(battle, attacker, target, skill_level)
  end
  
  def self.prevent_move_conflicts(battle, attacker, move, skill_level = 100)
    DoublesCoordination.prevent_move_conflicts(battle, attacker, move, skill_level)
  end
  
  def self.optimize_spread_moves(battle, attacker, move, skill_level = 100)
    DoublesCoordination.optimize_spread_moves(battle, attacker, move, skill_level)
  end
  
  def self.coordinate_field_effects(battle, attacker, move, skill_level = 100)
    DoublesCoordination.coordinate_field_effects(battle, attacker, move, skill_level)
  end
  
  def self.protect_setup_combo(battle, attacker, move, skill_level = 100)
    DoublesCoordination.protect_setup_combo(battle, attacker, move, skill_level)
  end
end

# Integration in Battle::AI
class Battle::AI
  def apply_doubles_coordination(score, move, user, target, skill = 100)
    return score unless @battle.pbSideSize(0) > 1
    return score unless AdvancedAI.feature_enabled?(:core, skill)
    
    score += AdvancedAI.prevent_overkill(@battle, user, target, skill) if target
    score += AdvancedAI.prevent_move_conflicts(@battle, user, move, skill)
    score += AdvancedAI.optimize_spread_moves(@battle, user, move, skill)
    score += AdvancedAI.coordinate_field_effects(@battle, user, move, skill)
    score += AdvancedAI.protect_setup_combo(@battle, user, move, skill)
    
    return score
  end
end

AdvancedAI.log("Doubles Coordination System loaded", "Doubles")
