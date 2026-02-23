#===============================================================================
# Advanced AI System - Dynamax Intelligence (DBK_005 Integration)
# Strategic Dynamax Timing and G-Max Optimization
#===============================================================================

class Battle::AI
  # Checks if Dynamax should be used
  def should_dynamax?(user, skill)
    return false unless skill >= 95
    return false unless AdvancedAI.dbk_enabled?(:dynamax)
    return false unless user.can_dynamax?
    return false if user.dynamax?
    
    score = calculate_dynamax_score(user, skill)
    
    AdvancedAI.log("Dynamax score for #{user.pbThis}: #{score}", "Dynamax")
    
    # Thresholds
    return true if score >= 100  # Excellent
    return true if score >= 70   # Strong
    return true if score >= 50 && remaining_pokemon_count(user) <= 2  # Good + few remaining
    
    return false
  end
  
  private
  
  def calculate_dynamax_score(user, skill)
    score = 0
    
    # 1. TIMING CONTEXT (0-35)
    score += evaluate_dynamax_timing(user, skill)
    
    # 2. OFFENSIVE VALUE (0-40)
    score += evaluate_dynamax_offensive(user, skill)
    
    # 3. SWEEP POTENTIAL (0-35)
    score += evaluate_dynamax_sweep(user, skill)
    
    # 4. SURVIVAL VALUE (0-45)
    score += evaluate_dynamax_survival(user, skill)
    
    # 5. PARTY COMPARISON (0 bis -25)
    score += evaluate_dynamax_party(user, skill)
    
    # 6. BATTLE MOMENTUM (0-30)
    score += evaluate_dynamax_momentum(user, skill)
    
    return score
  end
  
  # 1. Timing Context
  def evaluate_dynamax_timing(user, skill)
    score = 0
    turn = @battle.turnCount
    
    if turn <= 3
      # Early Game: Only for G-Max Steelsurge or Threat
      if user.gmax_move?(:STEELSURGE)
        score += 25
      elsif user.hp < user.totalhp * 0.4
        score += 20
      else
        score -= 10
      end
    elsif turn <= 8
      # Mid Game: Optimal
      score += 20
    else
      # Late Game: Cleanup or Desperation
      enemy_count = alive_enemies_count(user)
      if enemy_count == 1
        score += 15  # Cleanup
      elsif user.hp < user.totalhp * 0.5
        score += 25  # Comeback attempt
      end
    end
    
    # Team State Penalties
    alive = remaining_pokemon_count(user)
    score -= 10 if alive >= 5  # Too early
    
    return score
  end
  
  # 2. Offensive Value
  def evaluate_dynamax_offensive(user, skill)
    score = 0
    
    # Multiple Damage Types
    move_types = user.moves.select { |m| m && m.damagingMove? }.map { |m| m.type }.uniq
    score += move_types.count * 5
    
    # Strong Moves (80+ BP)
    strong_moves = user.moves.count { |m| m && m.damagingMove? && m.power >= 80 }
    score += strong_moves * 3
    
    # Coverage against Enemies
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      user.moves.each do |move|
        next unless move && move.damagingMove?
        type_mod = pbCalcTypeMod(move.type, target, user)
        score += 5 if Effectiveness.super_effective?(type_mod)
      end
    end
    
    # G-Max Moves Bonus
    score += 10 if user.gmax?
    
    # Choice Item Escape
    if user.item && [:CHOICEBAND, :CHOICESCARF, :CHOICESPECS].include?(user.item_id)
      score += 15
    end
    
    return [score, 40].min
  end
  
  # 3. Sweep Potential
  def evaluate_dynamax_sweep(user, skill)
    score = 0
    
    # Existing Stat Boosts
    positive_boosts = user.stages.values.count { |stage| stage > 0 }
    if positive_boosts >= 3
      score += 15
    elsif positive_boosts >= 1
      score += 8
    end
    
    # Max Move Boost Potential
    max_moves_with_boosts = user.moves.count do |move|
      next false unless move
      # Max Flare, Max Darkness, etc. give Boosts
      true  # Simplified
    end
    score += max_moves_with_boosts * 6
    
    # Speed Advantage
    faster_than_all = @battle.allOtherSideBattlers(user.index).all? do |target|
      next true unless target && !target.fainted?
      user.pbSpeed > target.pbSpeed
    end
    score += 10 if faster_than_all
    
    # Weak Enemies
    weak_enemies = @battle.allOtherSideBattlers(user.index).count do |target|
      next false unless target && !target.fainted?
      target.hp < target.totalhp * 0.4
    end
    score += weak_enemies * 4
    
    return [score, 35].min
  end
  
  # 4. Survival Value
  def evaluate_dynamax_survival(user, skill)
    score = 0
    hp_percent = user.hp.to_f / user.totalhp
    
    # Emergency HP Boost
    if hp_percent < 0.3
      score += 25
    elsif hp_percent < 0.5
      score += 15
    end
    
    # Prevent OHKO
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      target.moves.each do |move|
        next unless move && move.damagingMove?
        
        rough_damage = calculate_rough_damage(move, target, user)
        if rough_damage >= user.hp
          score += 20  # Would be KO without Dynamax
          break
        end
      end
    end
    
    # Dynamax Immunities
    # OHKO Immunity
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      has_ohko = target.moves.any? { |m| m && [:GUILLOTINE, :FISSURE, :SHEERCOLD, :HORNDRILL].include?(m.id) }
      score += 15 if has_ohko
    end
    
    # Remove Restrictions
    score += 10 if user.effects[PBEffects::Taunt] > 0
    score += 10 if user.effects[PBEffects::Torment]
    score += 10 if user.effects[PBEffects::NoRetreat]
    
    # Penalties
    score -= 30 if user.effects[PBEffects::PerishSong] > 0  # Waste
    
    return [score, 45].min
  end
  
  # 5. Party Comparison
  def evaluate_dynamax_party(user, skill)
    score = 0
    party = @battle.pbParty(user.index)
    
    # Better Dynamax Candidates?
    better_candidates = party.count do |pkmn|
      next false if !pkmn || pkmn.fainted? || pkmn.egg?
      next false if @battle.pbFindBattler(pkmn.index, user.index)
      
      # Higher Attack or Special Attack
      pkmn.attack > user.attack || pkmn.spatk > user.spatk
    end
    
    if better_candidates > 0
      score -= [better_candidates * 10, 20].min
    end
    
    # Last Pokemon Bonus
    alive = remaining_pokemon_count(user)
    score += 15 if alive == 1
    
    return score
  end
  
  # 6. Battle Momentum
  def evaluate_dynamax_momentum(user, skill)
    score = 0
    
    # Current Momentum
    if user_has_momentum?(user)
      score += 10
    end
    
    # Opponent Setup Pressure
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      positive_boosts = target.stages.values.count { |stage| stage > 0 }
      if positive_boosts >= 3
        score += 15
      elsif positive_boosts >= 1
        score += 8
      end
    end
    
    # G-Max Steelsurge Timing (if not yet set)
    if user.gmax_move?(:STEELSURGE)
      side = @battle.pbOwnedByPlayer?(user.index) ? @battle.sides[1] : @battle.sides[0]
      score += 10 unless side.effects[PBEffects::Gmaxsteelsurge]
    end
    
    # Field Effect Control
    if @battle.field.effects[PBEffects::Terrain] != :None
      score += 5
    end
    
    return [score, 30].min
  end
  
  # === HELPER METHODS ===
  
  def remaining_pokemon_count(user)
    @battle.pbParty(user.index).count { |p| p && !p.fainted? }
  end
  
  def alive_enemies_count(user)
    @battle.allOtherSideBattlers(user.index).count { |b| b && !b.fainted? }
  end
  
  def user_has_momentum?(user)
    # Simplified Momentum Check
    hp_advantage = user.hp.to_f / user.totalhp > 0.6
    stat_advantage = user.stages.values.sum > 0
    
    return hp_advantage && stat_advantage
  end
end

# Extended Battler Methods for Dynamax
class Battle::Battler
  def can_dynamax?
    return false unless defined?(Battle::Scene::USE_DYNAMAX_GRAPHICS)
    return @battle.pbCanDynamax?(@index)
  end
  
  def dynamax?
    return false unless defined?(Battle::Scene::USE_DYNAMAX_GRAPHICS)
    return dynamax_able?
  end
  
  def gmax?
    return false unless defined?(Battle::Scene::USE_DYNAMAX_GRAPHICS)
    return gmax_factor? && dynamax_able?
  end
  
  def gmax_move?(move_type)
    return false unless gmax?
    # Simplified G-Max Move Check
    return true
  end
end

AdvancedAI.log("Dynamax Intelligence loaded (DBK_005)", "Dynamax")
