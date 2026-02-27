#===============================================================================
# Advanced AI System - Switch Intelligence
# Intelligent Switching Decisions with Type Matchup and Momentum Control
#===============================================================================

class Battle::AI
  #=============================================================================
  # SWITCH ANALYZER - Evaluates switch opportunities
  #=============================================================================
  
  # Analyzes if AI should switch (advanced version)
  def should_switch_advanced?(user, skill = 100)
    return false unless user && !user.fainted?
    return false if user.trappedInBattle?
    return false unless AdvancedAI.feature_enabled?(:core, skill)
    
    # Initialize switch analysis cache
    @switch_analyzer[user.index] ||= {}
    cache = @switch_analyzer[user.index]
    
    # Calculate Switch Score
    switch_score = calculate_switch_score(user, skill)
    
    # Cache result
    cache[:last_score] = switch_score
    cache[:last_turn] = @battle.turnCount
    
    AdvancedAI.log("Switch score for #{user.pbThis}: #{switch_score}", "Switch")
    
    # Thresholds based on skill
    tier = AdvancedAI.get_ai_tier(skill)
    threshold = AdvancedAI::SWITCH_THRESHOLDS[tier] || 50
    
    return switch_score >= threshold
  end
  
  private # All methods below are private helper methods
  
  # Calculates Switch Score (0-100+)
  def calculate_switch_score(user, skill)
    echoln "  ┌─────────────────────────────────────┐"
    echoln "  │ SWITCH SCORE CALCULATION            │"
    echoln "  └─────────────────────────────────────┘"
    score = 0
    
    # 1. TYPE MATCHUP ANALYSIS (0-40 Points)
    type_score = evaluate_type_disadvantage(user, skill)
    score += type_score
    echoln("  [1/8] Type Disadvantage: +#{type_score}") if type_score > 0
    
    # 2. HP & STATUS ANALYSIS (0-30 Points)
    survival_score = evaluate_survival_concerns(user, skill)
    score += survival_score
    echoln("  [2/8] Survival Concerns: +#{survival_score}") if survival_score > 0
    
    # 3. STAT STAGE ANALYSIS (0-25 Points)
    stat_score = evaluate_stat_stages(user, skill)
    score += stat_score
    echoln("  [3/8] Stat Stage Loss: +#{stat_score}") if stat_score > 0
    
    # 4. BETTER OPTION AVAILABLE (0-35 Points)
    better_score = evaluate_better_options(user, skill)
    score += better_score
    echoln("  [4/8] Better Options: +#{better_score}") if better_score > 0
    
    # 5. MOMENTUM CONTROL (0-20 Points)
    if AdvancedAI.get_setting(:momentum_control) > 0
      momentum_score = evaluate_momentum(user, skill)
      score += momentum_score
      echoln("  [5/8] Momentum Control: +#{momentum_score}") if momentum_score > 0
    end
    
    # 6. PREDICTION BONUS (0-15 Points)
    if skill >= 85
      prediction_score = evaluate_prediction_advantage(user, skill)
      score += prediction_score
      echoln("  [6/8] Prediction: +#{prediction_score}") if prediction_score > 0
    end
    
    # 7. PENALTY: Losing Momentum (-20 Points)
    if user_has_advantage?(user)
      score -= 20
      echoln("  [7/8] Has Advantage (malus): -20")
    end
    
    # 8. PENALTY: Wasting Setup (-30 Points)
    if user.stages.values.any? { |stage| stage > 0 }
      total_boosts = user.stages.values.sum
      malus = [total_boosts * 10, 30].min
      score -= malus
      echoln("  [8/8] Wasting Setup +#{total_boosts} (malus): -#{malus}")
    end
    
    # 9. PENALTY: Switching too soon (-40 Points)
    if user.turnCount < 2
      score -= 40
      echoln("  [9/10] Just Switched In (malus): -40")
    end
    
    # 10. PENALTY: No better option (-15 Points)
    # If better_score is 0, it means either no switches exist OR the best switch isn't significantly better
    if better_score <= 0
      score -= 15
      echoln("  [10/10] No Better Option (malus): -15")
    end
    
    echoln "  ─────────────────────────────────────"
    echoln "  TOTAL SWITCH SCORE: #{score}"
    
    # Show Threshold
    tier = AdvancedAI.get_ai_tier(skill)
    threshold = AdvancedAI::SWITCH_THRESHOLDS[tier] || 50
    echoln "  Threshold (#{tier}): #{threshold}"
    echoln "  Decision: #{score >= threshold ? '✅ SWITCH' : '❌ STAY'}"
    
    return score
  end
  
  #=============================================================================
  # EVALUATION METHODS
  #=============================================================================
  
  # 1. Type Disadvantage Evaluation
  def evaluate_type_disadvantage(user, skill)
    score = 0
    
    # Use real types (ignoring Illusion) for defensive calculation
    my_types = get_real_types(user)
    
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      echoln("    → Analyzing vs #{target.name} [#{target.pbTypes(true).join('/')}]")
      
      # Offensive Threat (Opponent can hit User super effectively)
      target.moves.each do |move|
        next unless move
        next unless move.type # Fix ArgumentError
        type_mod = Effectiveness.calculate(move.type, *my_types)
        if Effectiveness.super_effective?(type_mod)
          score += 20  # Super effective move!
          echoln("      • #{move.name} [#{move.type}] → SUPER EFFECTIVE! (+20)")
        end
      end
      
      # Defensive Weakness (User cannot hit Opponent effectively)
      user_offensive = user.moves.map do |move|
        next 0 unless move
        next 0 unless move.type # Fix ArgumentError
        type_mod = Effectiveness.calculate(move.type, *target.pbTypes(true))
        Effectiveness.not_very_effective?(type_mod) ? 1.0 : 0.0
      end.count { |x| x > 0 }
      
      score += 10 if user_offensive >= 3  # Most moves not very effective
      
      # STAB Disadvantage
      target.moves.each do |move|
        next unless move
        next unless move.type # Fix ArgumentError
        if target.pbHasType?(move.type)  # STAB
          type_mod = Effectiveness.calculate(move.type, *my_types)
          score += 15 if Effectiveness.super_effective?(type_mod)
        end
      end
    end
    
    return [score, 40].min  # Cap at 40
  end
  
  # 2. Survival Concerns
  def evaluate_survival_concerns(user, skill)
    score = 0
    hp_percent = user.hp.to_f / user.totalhp
    
    # Low HP
    if hp_percent < 0.25
      score += 30
    elsif hp_percent < 0.40
      score += 20
    elsif hp_percent < 0.55
      score += 10
    end
    
    # No Recovery Options
    has_recovery = user.moves.any? do |m|
      next false unless m
      move_data = GameData::Move.try_get(m.id)
      next false unless move_data
      move_data.function_code.start_with?("HealUser") || 
        ["Roost", "Synthesis", "MorningSun", "Moonlight", "Recover", "Softboiled", "Wish", "Rest"].include?(move_data.real_name)
    end
    score += 10 if !has_recovery && hp_percent < 0.5
    
    # Bad Status
    if user.status != :NONE
      case user.status
      when :POISON, :BURN
        score += 15
      when :TOXIC
        score += 20
      when :SLEEP, :FROZEN
        score += 10
      when :PARALYSIS
        score += 5
      end
    end
    
    # OHKO Danger
    my_types = get_real_types(user)
    
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      # Faster Opponent with high Attack
      if target.pbSpeed > user.pbSpeed
        target.moves.each do |move|
          next unless move && move.damagingMove?
          next unless move.type
          
          type_mod = Effectiveness.calculate(move.type, *my_types)
          
          # Rough Damage Estimate
          if Effectiveness.super_effective?(type_mod)
            # Use safer base damage retrieval for v21.1 compatibility
            base_dmg = move.power
            estimated_damage = (target.attack * base_dmg * 2.0) / [user.defense, 1].max
            score += 15 if estimated_damage >= user.hp
          end
        end
      end
    end
    
    return [score, 30].min
  end
  
  # 3. Stat Stage Analysis
  def evaluate_stat_stages(user, skill)
    score = 0
    
    # Negative Stat Stages
    negative_stages = user.stages.values.count { |stage| stage < 0 }
    score += negative_stages * 8
    
    # Critical Drops
    score += 10 if user.stages[:ATTACK] <= -2 && user.attack > user.spatk
    score += 10 if user.stages[:SPECIAL_ATTACK] <= -2 && user.spatk > user.attack
    score += 12 if user.stages[:SPEED] <= -2
    
    # Opponent with many Boosts
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      positive_stages = target.stages.values.count { |stage| stage > 0 }
      score += 5 if positive_stages >= 2
      score += 10 if positive_stages >= 4
    end
    
    return [score, 25].min
  end
  
  # 4. Better Available Options
  def evaluate_better_options(user, skill)
    score = 0
    
    party = @battle.pbParty(user.index)
    available_switches = party.select.with_index do |pkmn, i|
      pkmn && !pkmn.fainted? && !pkmn.egg? && !@battle.pbFindBattler(i, user.index)
    end
    
    # Handle ReserveLastPokemon
    # Robust trainer retrieval
    ai_trainer = @trainer
    if !ai_trainer
      # Try to get trainer from battler
      ai_trainer = @battle.pbGetOwnerFromBattlerIndex(user.index)
    end

    if AdvancedAI::RESPECT_RESERVE_LAST_POKEMON && ai_trainer && ai_trainer.has_skill_flag?("ReserveLastPokemon")
      reserved_idx = party.length - 1
      echoln "[AAI DEBUG] ReserveLastPokemon Active! Reserved Index: #{reserved_idx}"
      
      # Only filter if we have more than 1 option (never restrict the last available mon)
      if available_switches.length > 1
        available_switches.reject! do |pkmn| 
          is_reserved = (party.index(pkmn) == reserved_idx)
          echoln "[AAI DEBUG] Filtering #{pkmn.name} (Index #{party.index(pkmn)})? #{is_reserved}" if is_reserved
          is_reserved
        end
      end
    else
      echoln "[AAI DEBUG] ReserveLastPokemon skipped. Enabled: #{AdvancedAI::RESPECT_RESERVE_LAST_POKEMON}, Trainer Found: #{!!ai_trainer}"
      if ai_trainer
         echoln "[AAI DEBUG] Has Flag? #{ai_trainer.has_skill_flag?("ReserveLastPokemon")}"
      end
    end
    
    return 0 if available_switches.empty?
    
    # Find best alternative
    best_matchup_score = -100
    best_switch = nil
    
    available_switches.each do |switch_mon|
      matchup = evaluate_switch_matchup(switch_mon, user)
      if matchup > best_matchup_score
        best_matchup_score = matchup
        best_switch = switch_mon
      end
    end
    
    return 0 unless best_switch
    
    # Calculate current pokemon's matchup for comparison
    # Pass user.pokemon (real Pokemon object) to evaluate current type effectiveness IGNORING Illusion
    current_matchup_score = evaluate_switch_matchup(user.pokemon, user)
    
    # Calculate improvement
    improvement = best_matchup_score - current_matchup_score
    
    echoln("[AAI Switch] Current: #{current_matchup_score} vs Best: #{best_matchup_score} (Diff: #{improvement})")
    
    # Bonus only if SIGNIFICANT improvement
    if improvement > 25
      score += 35
      echoln("[AAI Switch] Best Option: #{best_switch.name} (Matchup +#{best_matchup_score}, Improvement +#{improvement})")
    elsif improvement > 15
      score += 25
      echoln("[AAI Switch] Good Option: #{best_switch.name} (Matchup +#{best_matchup_score}, Improvement +#{improvement})")
    elsif improvement > 5 && best_matchup_score > 40
      # Only switch for small improvement if the matchup is absolutely excellent (Score > 40)
      score += 15
      echoln("[AAI Switch] Solid Option: #{best_switch.name} (Matchup +#{best_matchup_score}, Improvement +#{improvement})")
    end
    
    return score
  end
  
  # 5. Momentum Control
  def evaluate_momentum(user, skill)
    score = 0
    
    # Force Momentum Shift if behind
    alive_user = @battle.pbParty(user.index).count { |p| p && !p.fainted? }
    alive_enemy = @battle.allOtherSideBattlers(user.index).count { |b| 
      b && !b.fainted? && @battle.pbParty(b.index).count { |p| p && !p.fainted? } > 0
    }
    
    if alive_user < alive_enemy
      score += 10  # Attempt Momentum Shift
    end
    
    # Predict Switch if opponent wants to setup
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      # Opponent has Setup Moves (check function codes)
      has_setup = target.moves.any? do |m|
        next false unless m && m.is_a?(Battle::Move) && m.statusMove?
        move_data = GameData::Move.try_get(m.id)
        next false unless move_data
        # Setup moves have function codes like RaiseUserAttack2, RaiseMultipleStats, etc.
        move_data.function_code.to_s.include?("RaiseUser") || move_data.function_code.to_s.include?("RaiseMulti")
      end
      score += 15 if has_setup && user_has_type_disadvantage?(user, target)
    end
    
    return [score, 20].min
  end
  
  # 6. Prediction Advantage (Skill 85+)
  def evaluate_prediction_advantage(user, skill)
    return 0 unless skill >= 85
    score = 0
    
    # If opponent likely switches, stay in
    # If opponent likely setups, switch out
    
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      # Analyze last moves
      if @move_memory[target.index]
        last_moves = @move_memory[target.index][:moves] || []
        
        # Pattern: Repeated Setup Moves
        setup_count = last_moves.count do |m|
          next false unless m
          move_data = GameData::Move.try_get(m)
          next false unless move_data
          move_data.function_code.to_s.include?("RaiseUser") || move_data.function_code.to_s.include?("RaiseMulti")
        end
        score += 10 if setup_count >= 2
        
        # Pattern: Predict Opponent Switch (if low HP)
        if target.hp < target.totalhp * 0.35
          score -= 15  # Stay in, opponent likely switches
        end
      end
    end
    
    return [score, 15].min
  end
  
  #=============================================================================
  # FIND BEST SWITCH OPTION
  #=============================================================================
  
  # Detailed Switch Candidate Evaluation
  def evaluate_switch_candidate_detailed(pkmn, current_user, skill)
    score = 50  # Base score
    
    # 1. TYPE MATCHUP (0-50 Points)
    score += evaluate_switch_matchup(pkmn, current_user)
    
    # 2. HP & STATUS (0-20 Points)
    hp_percent = pkmn.hp.to_f / pkmn.totalhp
    score += (hp_percent * 20).to_i
    score -= 20 if pkmn.status != :NONE
    
    # 3. SPEED (0-15 Points)
    # Note: pkmn is Pokemon (not Battler), need to calculate speed properly
    @battle.allOtherSideBattlers(current_user.index).each do |target|
      next unless target && !target.fainted?
      # Use base speed stat for Pokemon comparison (pkmn doesn't have pbSpeed)
      pkmn_speed = pkmn.speed
      target_speed = target.speed  # Use base speed for fair comparison
      score += 15 if pkmn_speed > target_speed
    end
    
    # 4. ROLE ANALYSIS (0-25 Points)
    role_bonus = evaluate_switch_role(pkmn, current_user, skill)
    score += role_bonus
    
    # 5. ENTRY HAZARDS RESISTANCE (0-15 Points)
    if @battle.pbOwnedByPlayer?(current_user.index)
      opponent_side = @battle.sides[1]
    else
      opponent_side = @battle.sides[0]
    end
    
    # Stealth Rock Resistance
    if opponent_side.effects[PBEffects::StealthRock]
      effectiveness = Effectiveness.calculate(:ROCK, pkmn.types[0], pkmn.types[1])
      if Effectiveness.ineffective?(effectiveness)
        score += 15
      elsif Effectiveness.not_very_effective?(effectiveness)
        score += 10
      elsif Effectiveness.super_effective?(effectiveness)
        score -= 15
      end
    end
    
    # Spikes
    if opponent_side.effects[PBEffects::Spikes] > 0
      # Safe ability check with nil guard
      has_levitate = false
      begin
        has_levitate = pkmn.hasAbility?(:LEVITATE) if pkmn.respond_to?(:hasAbility?)
      rescue
        has_levitate = false
      end
      score += 10 if pkmn.hasType?(:FLYING) || has_levitate
    end
    
    # 6. ABILITY SYNERGY (0-20 Points)
    # Use ability_id instead of ability to avoid Gen9 Pack recursion
    ability_id = nil
    begin
      ability_id = pkmn.ability_id if pkmn.respond_to?(:ability_id)
    rescue StandardError => e
      AdvancedAI.log("Error getting ability_id: #{e.message}", "Switch")
    end
    
    if ability_id
      # Intimidate on Switch-In
      score += 20 if ability_id == :INTIMIDATE
      
      # Weather/Terrain abilities
      score += 15 if [:DRIZZLE, :DROUGHT, :SANDSTREAM, :SNOWWARNING].include?(ability_id)
      
      # Defensive abilities
      score += 10 if [:REGENERATOR, :NATURALCURE, :IMMUNITY].include?(ability_id)
    end
    
    return score
  end
  
  # Matchup Evaluation for Switch
  def evaluate_switch_matchup(switch_mon, current_user)
    score = 0
    
    # Validate types
    # Validate types - normalize input to types array
    switch_types = []
    
    if switch_mon.is_a?(Battle::Battler)
       # Use real types helper if it's a battler (Illusion bypass)
       switch_types = get_real_types(switch_mon)
    elsif switch_mon.respond_to?(:types)
       # Pokemon object
       switch_types = [switch_mon.types[0], switch_mon.types[1]].compact
    end
    
    return 0 if switch_types.empty?
    
    @battle.allOtherSideBattlers(current_user.index).each do |target|
      next unless target && !target.fainted?
      
      # Offensive Type Advantage
      switch_mon_types = switch_types.uniq
      return 0 if switch_mon_types.empty?
      
      target_types = [target.types[0], target.types[1]].compact
      next if target_types.empty?
      
      switch_mon_types.each do |type|
        next unless type  # Skip nil
        effectiveness = Effectiveness.calculate(type, *target_types)
        if Effectiveness.super_effective?(effectiveness)
          score += 20
        elsif Effectiveness.not_very_effective?(effectiveness)
          score -= 10
        elsif Effectiveness.ineffective?(effectiveness)
          score -= 40  # STAB ineffective (Immunity)
        end
      end
      
      # Defensive Type Advantage
      target.moves.each do |move|
        next unless move && move.damagingMove?
        next unless move.type  # Skip nil types
        switch_types = [switch_mon.types[0], switch_mon.types[1]].compact
        next if switch_types.empty?
        effectiveness = Effectiveness.calculate(move.type, *switch_types)
        if Effectiveness.ineffective?(effectiveness)
          score += 40  # IMMUNITY is extremely valuable!
        elsif Effectiveness.not_very_effective?(effectiveness)
          score += 15  # Resistance is good
        elsif Effectiveness.super_effective?(effectiveness)
          score -= 25  # Weakness is bad
        end
      end
    end
    
    return score
  end
  
  # Role-based Switch Evaluation
  def evaluate_switch_role(pkmn, current_user, skill)
    return 0 unless skill >= 55
    score = 0
    
    # Determine Role of current Pokemon
    current_role = determine_pokemon_role(current_user)
    switch_role = determine_pokemon_role_from_stats(pkmn)
    
    # Prefer Complementary Roles
    case current_role
    when :sweeper
      score += 15 if [:wall, :tank].include?(switch_role)
    when :wall
      score += 15 if [:sweeper, :wallbreaker].include?(switch_role)
    when :support
      score += 20 if [:sweeper, :wallbreaker].include?(switch_role)
    end
    
    return score
  end
  
  # Find best switch Pokemon (public for Core.rb integration)
  def find_best_switch_advanced(user, skill)
    echoln "  ┌─────────────────────────────────────┐"
    echoln "  │ FINDING BEST REPLACEMENT            │"
    echoln "  └─────────────────────────────────────┘"
    
    party = @battle.pbParty(user.index)
    available_switches = []
    
    reserved_idx = -1
    if AdvancedAI::RESPECT_RESERVE_LAST_POKEMON && @trainer && @trainer.has_skill_flag?("ReserveLastPokemon")
      reserved_idx = party.length - 1
    end
    
    party.each_with_index do |pkmn, i|
      next unless pkmn && !pkmn.fainted? && !pkmn.egg?
      next if @battle.pbFindBattler(i, user.index) # Already in battle
      next unless @battle.pbCanSwitchIn?(user.index, i)
      
      matchup_score = evaluate_switch_matchup_detailed(pkmn, user)
      available_switches.push([pkmn, matchup_score, i])
      
      echoln "  • #{pkmn.name}: Matchup = #{matchup_score}"
    end
    
    # Filter reserved Pokemon
    # 1. If we have multiple options, always save the Ace
    # 2. If we only have the Ace left:
    #    - If VOLUNTARY switch (user not fainted), save the Ace (stay in and die)
    #    - If FORCED switch (user fainted), we must use the Ace (no choice)
    
    is_voluntary_switch = user && !user.fainted?
    
    if reserved_idx >= 0
      should_filter = false
      
      if available_switches.length > 1
        should_filter = true
      elsif is_voluntary_switch && available_switches.length == 1
        # Strict Mode: Don't bring out Ace to save a dying mon
        should_filter = true
        echoln "  [AAI] ReserveLastPokemon: Blocking voluntary switch to Ace"
      end
      
      if should_filter
        available_switches.reject! { |item| item[2] == reserved_idx }
        if available_switches.empty?
          echoln "  [AAI] Reserved Pokemon at index #{reserved_idx} excluded (No other options)"
        else
          echoln "  [AAI] Reserved Pokemon at index #{reserved_idx} excluded from options"
        end
      end
    end
    
    if available_switches.empty?
      echoln "  >>> No valid switches available!"
      return nil
    end
    
    # Sort by matchup score (highest first)
    available_switches.sort_by! { |_, score, _| -score }
    best_pkmn, best_score, best_idx = available_switches.first
    
    echoln "  ─────────────────────────────────────"
    echoln "  ✅ BEST OPTION: #{best_pkmn.name}"
    echoln "  Matchup Score: #{best_score}"
    
    # Return party index directly (Core.rb expects integer)
    return best_idx
  end
  
  private
  
  # Detailed Matchup Evaluation for Switch Selection
  def evaluate_switch_matchup_detailed(switch_pkmn, current_user)
    score = 0
    
    # Validate switch_pkmn has types
    return 0 unless switch_pkmn && switch_pkmn.types
    switch_types = [switch_pkmn.types[0], switch_pkmn.types[1]].compact
    return 0 if switch_types.empty? || switch_types.any?(&:nil?)
    
    # Analyze against all opponents
    @battle.allOtherSideBattlers(current_user.index).each do |target|
      next unless target && !target.fainted?
      
      target_types = target.pbTypes(true).compact
      next if target_types.empty? || target_types.any?(&:nil?)
      
      # Defensive Matchup (Incoming Moves)
      target.moves.each do |move|
        next unless move && move.damagingMove?
        next unless move.type  # Skip if move has no type
        
        move_type = move.pbCalcType(target)  # target is already a Battle::Battler
        next unless move_type  # Skip if calculated type is nil
        
        # Additional safety: ensure all switch types are valid
        next if switch_types.any? { |t| t.nil? }
        
        eff = Effectiveness.calculate(move_type, *switch_types)
        
        if Effectiveness.ineffective?(eff)
          score += 40
        elsif Effectiveness.not_very_effective?(eff)
          score += 15
        elsif Effectiveness.super_effective?(eff)
          score -= 25
        end
      end
      
      # Offensive Matchup (Outgoing Moves)
      switch_pkmn.moves.each do |move|
        next unless move && move.id
        move_data = GameData::Move.try_get(move.id)
        next unless move_data
        next if move_data.category == 2  # Skip status moves (0=Physical, 1=Special, 2=Status)
        next unless move_data.type  # Skip if move has no type
        
        # Additional safety: ensure all target types are valid
        next if target_types.any? { |t| t.nil? }
        
        eff = Effectiveness.calculate(move_data.type, *target_types)
        
        if Effectiveness.super_effective?(eff)
          score += 20
        elsif Effectiveness.ineffective?(eff)
          score -= 40  # Useless move
        end
      end
    end
    
    return score
  end

  #=============================================================================
  # HELPER METHODS
  #=============================================================================
  
  def user_has_advantage?(user)
    my_types = get_real_types(user)
    
    @battle.allOtherSideBattlers(user.index).all? do |target|
      next true unless target && !target.fainted?
      
      # Type advantage
      user.moves.any? do |move|
        next false unless move && move.damagingMove?
        next false unless move.type
        type_mod = Effectiveness.calculate(move.type, *target.pbTypes(true))
        Effectiveness.super_effective?(type_mod)
      end
    end
  end
  
  def user_has_type_disadvantage?(user, target)
    my_types = get_real_types(user)
    
    target.moves.any? do |move|
      next false unless move && move.damagingMove?
      next false unless move.type
      type_mod = Effectiveness.calculate(move.type, *my_types)
      Effectiveness.super_effective?(type_mod)
    end
  end
  
  def determine_pokemon_role(battler)
    # Simplified role detection (will be expanded in [011])
    if battler.attack > battler.spatk && battler.speed > 100
      return :sweeper
    elsif battler.defense > 100 || battler.spdef > 100
      return :wall
    else
      return :balanced
    end
  end
  
  # Helper to get REAL types (ignoring Illusion)
  def get_real_types(battler)
    # If Illusion is active (effects[PBEffects::Illusion] is truthy/Pokemon object),
    # return the types of the underlying Pokemon
    return battler.pokemon.types if battler.effects[PBEffects::Illusion]
    
    # Otherwise return current effective types (includes Soak etc)
    return battler.pbTypes(true)
  end
  
  def determine_pokemon_role_from_stats(pkmn)
    # Simplified role detection
    if pkmn.attack > pkmn.spatk && pkmn.speed > 100
      return :sweeper
    elsif pkmn.defense > 100 || pkmn.spdef > 100
      return :wall
    else
      return :balanced
    end
  end
end

AdvancedAI.log("Switch Intelligence loaded", "Switch")
