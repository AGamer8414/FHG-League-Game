#===============================================================================
# Advanced AI System - Move Scorer
# Intelligent Move Scoring with 20+ Factors
#===============================================================================

class Battle::AI
  # Enhanced Move Scoring Logic
  def score_move_advanced(move, user, target, skill)
    return 0 unless move && user && target
    
    base_score = 100  # Neutral Start
    
    # === DAMAGE ANALYSIS ===
    if move.damagingMove?
      base_score += score_damage_potential(move, user, target, skill)
      base_score += score_type_effectiveness(move, user, target)
      base_score += score_stab_bonus(move, user)
      base_score += score_crit_potential(move, user, target)
    end
    
    # === STATUS ANALYSIS ===
    if move.statusMove?
      base_score += score_status_utility(move, user, target, skill)
    end
    
    # === SETUP ANALYSIS ===
    if move.function_code.start_with?("RaiseUser") || AdvancedAI.setup_move?(move.id)
      base_score += score_setup_value(move, user, target, skill)
    end
    
    # === SITUATIONAL FACTORS ===
    base_score += score_priority(move, user, target)
    base_score += score_accuracy(move, skill)
    base_score += score_recoil_risk(move, user)
    base_score += score_secondary_effects(move, user, target)
    
    return base_score
  end
  
  private
  
  # Damage Potential
  def score_damage_potential(move, user, target, skill)
    score = 0
    
    # Effective Base Power (Factors in Multi-Hits, Skill Link, etc.)
    bp = calculate_effective_power(move, user, target)
    
    # Base Power Bonus
    score += (bp / 10.0) if bp > 0
    
    # KO Potential
    if skill >= 60
      # Use effective BP for damage calc
      rough_damage = calculate_rough_damage(move, user, target, bp)
      if rough_damage >= target.hp
        score += 100  # Guaranteed KO
      elsif rough_damage >= target.hp * 0.7
        score += 50   # Likely KO
      elsif rough_damage >= target.hp * 0.4
        score += 25
      end
    end
    
    # Multi-Target Bonus
    score += 30 if move.pbTarget(user).num_targets > 1 && @battle.pbSideSize(0) > 1
    
    return score
  end
  
  # Type Effectiveness
  def score_type_effectiveness(move, user, target)
    type_mod = pbCalcTypeMod(move.type, target, user)
    
    if Effectiveness.super_effective?(type_mod)
      return 40
    elsif Effectiveness.not_very_effective?(type_mod)
      return -30
    elsif Effectiveness.ineffective?(type_mod)
      return -200
    end
    
    return 0
  end
  
  # STAB Bonus
  def score_stab_bonus(move, user)
    return 20 if user.pbHasType?(move.type)
    return 0
  end
  
  # Critical Hit Potential
  def score_crit_potential(move, user, target)
    score = 0
    
    # 1. Critical Immunity Check
    # If target has Battle Armor, Shell Armor, or Lucky Chant, crits are impossible/unlikely
    return 0 if target.hasActiveAbility?(:BATTLEARMOR) || target.hasActiveAbility?(:SHELLARMOR)
    return 0 if target.pbOwnSide.effects[PBEffects::LuckyChant] > 0
    
    # Check for High Crit Rate Move
    is_high_crit = (move.function_code == "HighCriticalHitRate")
    is_always_crit = move.function_code.include?("AlwaysCriticalHit")
    
    # 2. Synergy: Focus Energy + High Crit Move
    # Focus Energy (+2 stages) + High Crit Move (+1 stage) = +3 stages (100% Crit)
    # NOTE: Do NOT give a synergy bonus for AlwaysCriticalHit moves, because Focus Energy
    # adds nothing to them (they already crit).
    if user.effects[PBEffects::FocusEnergy] > 0
      if is_high_crit
        score += 50  # Massive bonus for correctly using the combo
      elsif !is_always_crit
        # Focus Energy alone gives 50% crit rate (Stage 2)
        # Still good for normal moves, but useless for AlwaysCrit moves
        score += 20
      end
    elsif is_high_crit
      # High Crit Move alone is 1/8 chance (Stage 1), decent but not reliable
      score += 15
    end
    
    # 3. Ignore Stat Changes
    # Critical hits ignore the target's positive defense stages...
    ignore_target_def = (target.stages[:DEFENSE] > 0 && move.physical?) || 
                        (target.stages[:SPECIAL_DEFENSE] > 0 && move.special?)
    
    # ...AND they ignore the user's negative attack stages!
    ignore_user_debuff = (user.stages[:ATTACK] < 0 && move.physical?) || 
                         (user.stages[:SPECIAL_ATTACK] < 0 && move.special?)
    
    if ignore_target_def || ignore_user_debuff
      # Only apply this bonus if we have a RELIABLE crit chance
      # (Focus Energy active OR Move always crits)
      if user.effects[PBEffects::FocusEnergy] > 0 || move.function_code.include?("AlwaysCriticalHit")
        score += 30 # Value bypassing the stats
      end
    end
    
    return score
  end
  
  # Status Move Utility
  def score_status_utility(move, user, target, skill)
    score = 0
    
    # Determine opponent side (for hazards)
    opponent_side = @battle.pbOwnedByPlayer?(target.index) ? @battle.sides[1] : @battle.sides[0]
    
    case move.function_code
    # Hazards
    when "AddSpikesToFoeSide"
      score += 60 if opponent_side.effects[PBEffects::Spikes] < 3
    when "AddStealthRocksToFoeSide"
      score += 70 unless opponent_side.effects[PBEffects::StealthRock]
    when "AddToxicSpikesToFoeSide"
      score += 50 if opponent_side.effects[PBEffects::ToxicSpikes] < 2
    when "AddStickyWebToFoeSide"
      # Score high if opponent side has no sticky web and we aren't faster
      score += 60 unless opponent_side.effects[PBEffects::StickyWeb]
    # Screens
    when "StartWeakenPhysicalDamageAgainstUserSide" # Reflect
      if user.pbOwnSide.effects[PBEffects::Reflect] == 0
        score += 50 
        # Bonus if opponent's last move was Physical
        if target.lastRegularMoveUsed
          move_data = GameData::Move.try_get(target.lastRegularMoveUsed)
          score += 40 if move_data&.physical?
        end
      end
    when "StartWeakenSpecialDamageAgainstUserSide" # Light Screen
      if user.pbOwnSide.effects[PBEffects::LightScreen] == 0
        score += 50
        # Bonus if opponent's last move was Special
        if target.lastRegularMoveUsed
          move_data = GameData::Move.try_get(target.lastRegularMoveUsed)
          score += 40 if move_data&.special?
        end
      end
    when "StartWeakenDamageAgainstUserSideIfHail" # Aurora Veil
      if (@battle.pbWeather == :Hail || @battle.pbWeather == :Snow) && user.pbOwnSide.effects[PBEffects::AuroraVeil] == 0
        score += 60
        # Bonus if opponent's last move was Damaging
        if target.lastRegularMoveUsed
          move_data = GameData::Move.try_get(target.lastRegularMoveUsed)
          score += 40 if move_data&.damaging?
        end
      end
      
    # Recovery
    when "HealUserHalfOfTotalHP", "HealUserDependingOnWeather"
      hp_percent = user.hp.to_f / user.totalhp
      score += 80 if hp_percent < 0.3
      score += 50 if hp_percent < 0.5
      score += 20 if hp_percent < 0.7
      
    # Status Infliction
    when "ParalyzeTarget"
      score += 40 if target.pbSpeed > user.pbSpeed && target.status == :NONE
    when "BurnTarget"
      score += 50 if target.attack > target.spatk && target.status == :NONE
    when "PoisonTarget", "BadPoisonTarget"
      score += 45 if target.status == :NONE && target.hp > target.totalhp * 0.7
      
    # Stat Drops
    when "LowerTargetAttack1", "LowerTargetAttack2"
      score += 30 if target.attack > target.spatk
    when "LowerTargetSpeed1", "LowerTargetSpeed2"
      score += 35 if target.pbSpeed > user.pbSpeed
    when "LowerTargetDefense1", "LowerTargetDefense2"
      score += 25 if user.attack > user.spatk
    end
    
    return score
  end
  
  # Setup Value
  def score_setup_value(move, user, target, skill)
    return 0 unless skill >= 55
    score = 0
    
    # Safe to setup?
    safe_to_setup = is_safe_to_setup?(user, target)
    
    if safe_to_setup

      # Boost Strength
      total_boosts = 0
      
      # Try to get data from MoveCategories
      setup_data = AdvancedAI.get_setup_data(move.id)
      if setup_data
        total_boosts = setup_data[:stages] || 1
      elsif move.function_code.start_with?("RaiseUser")
        # Extract boost amount from function code (e.g., "RaiseUserAttack1" -> 1)
        total_boosts = move.function_code.scan(/\d+/).last.to_i
        total_boosts = 1 if total_boosts == 0 # Default to 1 if no number (e.g., "RaiseUserAllStats1")
      else
        total_boosts = 1
      end
      score += total_boosts * 20
      
      # Sweep Potential
      if user.hp > user.totalhp * 0.7
        score += 30
      end
    else
      score -= 40  # Dangerous to setup
    end
    
    return score
  end
  
  # Priority
  def score_priority(move, user, target)
    return 0 if move.priority <= 0
    
    score = move.priority * 15
    
    # 1. Desperation Logic: User Low HP & Slower
    if user.hp <= user.totalhp * 0.33 && target.pbSpeed > user.pbSpeed
      score += 40 
    end

    # 2. Priority Blockers
    if move.priority > 0
      # Psychic Terrain (blocks priority against grounded targets)
      if @battle.field.terrain == :Psychic && target.affectedByTerrain?
        return -100
      end
      
      # Ability Blockers (Dazzling, Queenly Majesty, Armor Tail)
      # These abilities block priority moves targeting the user
      blocking_abilities = [:DAZZLING, :QUEENLYMAJESTY, :ARMORTAIL]
      if blocking_abilities.include?(target.ability_id) && !user.hasMoldBreaker?
        return -100
      end
    end
    
    # Extra Bonus if slower
    score += 30 if target.pbSpeed > user.pbSpeed
    
    # Extra Bonus if KO possible
    if move.damagingMove?
      rough_damage = calculate_rough_damage(move, user, target)
      score += 40 if rough_damage >= target.hp
    end
    
    return score
  end
  
  # Accuracy
  def score_accuracy(move, skill)
    accuracy = move.accuracy
    return 0 if accuracy == 0  # Never-miss moves
    
    if accuracy < 70
      return -40
    elsif accuracy < 85
      return -20
    elsif accuracy < 95
      return -10
    end
    
    return 0
  end
  
  # Recoil Risk
  def score_recoil_risk(move, user)
    return 0 unless move.recoilMove?
    
    hp_percent = user.hp.to_f / user.totalhp
    
    if hp_percent < 0.3
      return -50  # Dangerous at low HP
    elsif hp_percent < 0.5
      return -25
    else
      return -10  # Acceptable risk
    end
  end
  
  # Secondary Effects
  def score_secondary_effects(move, user, target)
    score = 0
    
    # Flinch
    if move.flinchingMove?
      score += 20 if user.pbSpeed > target.pbSpeed
    end
    
    # Stat Drops on Target
    if move.function_code.start_with?("LowerTarget")
      score += 20 # Simplified score
    end
    
    # Status Chance
    if ["ParalyzeTarget", "BurnTarget", "PoisonTarget", "SleepTarget", "FreezeTarget"].any? {|code| move.function_code.include?(code)}
      score += move.addlEffect / 2
    end
    
    return score
  end
  
  # === HELPER METHODS ===
  
  def calculate_rough_damage(move, user, target, override_bp = nil)
    return 0 unless move.damagingMove?
    
    # Very Simplified Damage Calculation
    bp = override_bp || move.power
    return 0 if bp == 0
    
    atk = move.physicalMove? ? user.attack : user.spatk
    defense = move.physicalMove? ? target.defense : target.spdef
    
    type_mod = pbCalcTypeMod(move.type, target, user)
    stab = user.pbHasType?(move.type) ? 1.5 : 1.0
    
    damage = ((2 * user.level / 5.0 + 2) * bp * atk / defense / 50 + 2)
    damage *= type_mod
    damage *= stab
    
    return damage.to_i
  end
  
  def is_safe_to_setup?(user, target)
    # HP Check
    return false if user.hp < user.totalhp * 0.5
    
    # Speed Check
    return false if target.pbSpeed > user.pbSpeed * 1.5
    
    # Type Matchup Check
    target.moves.each do |move|
      next unless move && move.damagingMove?
      type_mod = pbCalcTypeMod(move.type, user, target)
      return false if Effectiveness.super_effective?(type_mod)
    end
    
    return true
  end
  
  # Calculates effective base power including multi-hit factors
  def calculate_effective_power(move, user, target)
    bp = move.power
    return 0 if bp == 0
    
    # Always Critical Hit Logic (e.g. Flower Trick, Frost Breath)
    if move.function_code.include?("AlwaysCriticalHit")
      # Check immunity
      is_immune = target.hasActiveAbility?(:BATTLEARMOR) || 
                  target.hasActiveAbility?(:SHELLARMOR) ||
                  target.pbOwnSide.effects[PBEffects::LuckyChant] > 0
      
      unless is_immune
        bp = (bp * 1.5).to_i
      end
    end
    
    return bp unless move.multiHitMove? || move.function_code == "HitTwoTimes"
    
    if move.multiHitMove?
      if user.hasActiveAbility?(:SKILLLINK)
        return bp * 5
      elsif user.hasActiveItem?(:LOADEDDICE)
        return bp * 4 # Average 4-5 hits
      elsif move.pbNumHits(user, [target]) == 2 # Fixed 2-hit moves check
         return bp * 2
      else
         return bp * 3 # Average for 2-5 hit moves
      end
    elsif move.function_code == "HitTwoTimes"
       return bp * 2
    end
    
    return bp
  end
end

AdvancedAI.log("Move Scorer loaded", "Scorer")
