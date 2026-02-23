#===============================================================================
# Advanced AI System - Mechanics Hooks
# Connects Intelligence Modules to Battle System
#===============================================================================

class Battle::AI
  #-----------------------------------------------------------------------------
  # Main Hook: Register Enemy Special Actions
  # This is where the AI decides to use gimmicks (Mega, Z-Move, Dynamax, Tera)
  #-----------------------------------------------------------------------------
  if method_defined?(:pbRegisterEnemySpecialAction)
    alias aai_pbRegisterEnemySpecialAction pbRegisterEnemySpecialAction 
    def pbRegisterEnemySpecialAction(idxBattler)
      # 1. Call original (handles vanilla or other plugin logic)
      aai_pbRegisterEnemySpecialAction(idxBattler)
      
      # 2. Get user context
      run_advanced_ai_special_actions(idxBattler)
    end
  else
    # If method doesn't exist (Essentials v21.1 or different plugin order),
    # we define it. Ensure this is called by the Battle Engine or your loops.
    # Note: In vanilla v21.1, this method might not exist.
    # We hook into pbChooseEnemyAction usually, but if this is intended as a standalone
    # method for other plugins to call, we define it.
    def pbRegisterEnemySpecialAction(idxBattler)
      run_advanced_ai_special_actions(idxBattler)
    end
  end

  def run_advanced_ai_special_actions(idxBattler)
    
    # 2. Get user context
    skill = @trainer&.skill || 100
    return unless AdvancedAI.qualifies_for_advanced_ai?(skill)
    
    # 3. Decision Pipeline
    # Priority: Mega > Z-Move > Dynamax > Tera
    # (Triggers are mutually exclusive usually per turn)
    
    # --- MEGA EVOLUTION ---
    if AdvancedAI.feature_enabled?(:mega_evolution, skill) && should_mega_evolve?(@user, skill)
      @battle.pbRegisterMegaEvolution(idxBattler)
      AdvancedAI.log("#{@user.name} registered Mega Evolution", "Hooks")
      return # Use one gimmick per turn decision to avoid conflicts
    end
    
    # --- Z-MOVES ---
    if AdvancedAI.feature_enabled?(:z_moves, skill) && should_z_move?(@user, skill)
      @battle.pbRegisterZMove(idxBattler)
      AdvancedAI.log("#{@user.name} registered Z-Move", "Hooks")
      return
    end
    
    # --- DYNAMAX ---
    if AdvancedAI.feature_enabled?(:dynamax, skill) && should_dynamax?(@user, skill)
      @battle.pbRegisterDynamax(idxBattler)
      AdvancedAI.log("#{@user.name} registered Dynamax", "Hooks")
      return
    end
    
    # --- TERASTALLIZATION ---
    if AdvancedAI.feature_enabled?(:terastallization, skill) && should_terastallize?(@user, skill)
      @battle.pbRegisterTerastallize(idxBattler)
      AdvancedAI.log("#{@user.name} registered Terastallization", "Hooks")
      return
    end
  end
end

AdvancedAI.log("Advanced AI Mechanics Hooks registered", "Hooks")
