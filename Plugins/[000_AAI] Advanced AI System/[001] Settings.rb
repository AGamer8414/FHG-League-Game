#===============================================================================
# Advanced AI System - Settings & Configuration
# Version: 1.0.0
# Compatible: Pokemon Essentials v21.1+, All DBK Plugins
#===============================================================================

module AdvancedAI
  # ============================================================================
  # CORE SETTINGS
  # ============================================================================
  
  # Enable/Disable the entire system
  ENABLED = true
  
  # Auto-activate with Challenge Modes plugin (if installed)
  ACTIVATE_WITH_CHALLENGE_MODES = true
  
  # Minimum skill level for auto-activation
  MIN_SKILL_FOR_AUTO_ACTIVATION = 70
  
  # Debug mode - detailed logging
  DEBUG_MODE = true
  
  # ============================================================================
  # SKILL LEVEL THRESHOLDS
  # ============================================================================
  
  # Defines which AI features are enabled at each skill level
  SKILL_THRESHOLDS = {
    :core              => 50,   # Core AI (Move Scoring, Memory, Threats)
    :switch_intelligence => 50, # Switch Intelligence (Type matchup analysis)
    :setup             => 55,   # Setup Recognition
    :endgame           => 60,   # Endgame Scenarios (1v1, 2v2)
    :personalities     => 65,   # Battle Personalities
    :items             => 85,   # Item Intelligence
    :prediction        => 85,   # Prediction System
    :mega_evolution    => 90,   # Mega Evolution Intelligence
    :z_moves           => 90,   # Z-Move Intelligence (DBK_004)
    :dynamax           => 90,   # Dynamax Intelligence (DBK_005)
    :terastallization  => 90   # Terastallization (DBK_006)
  }
  
  # Switch decision thresholds by AI mode (simplified to 3 tiers)
  # Higher threshold = Less likely to switch (Must be in more danger)
  SWITCH_THRESHOLDS = {
    :beginner => 65,  # Skill 0-60: Stays in until very dangerous
    :mid      => 55,  # Skill 61-85: Balanced switching
    :pro      => 45   # Skill 86+: Aggressive but stable switching (was 35)
  }
  
  # ============================================================================
  # ADVANCED FLAGS (Bit Flags for Fine-Tuning)
  # ============================================================================
  
  # Use bit flags for granular control
  # Example: 0b00000001 = Enable switch-ins prediction
  #          0b00000010 = Enable setup chain detection
  #          0b00000100 = Enable hazard calculations
  
  ADVANCED_FLAGS = {
    :switch_prediction    => 0b00000001,  # Predict opponent switches
    :setup_chains         => 0b00000010,  # Detect setup chains (Baton Pass)
    :hazard_calc          => 0b00000100,  # Calculate hazard damage
    :weather_abuse        => 0b00001000,  # Abuse weather conditions
    :terrain_abuse        => 0b00010000,  # Abuse terrain conditions
    :ko_prediction        => 0b00100000,  # Predict KO scenarios
    :revenge_kill         => 0b01000000,  # Prevent revenge kills
    :momentum_control     => 0b10000000   # Control battle momentum
  }
  
  # Default flags (all enabled for skill 100+)
  DEFAULT_FLAGS = 0b11111111
  
  # ============================================================================
  # PERSONALITY SETTINGS
  # ============================================================================
  
  # Auto-detect personality from team composition
  AUTO_DETECT_PERSONALITY = true
  
  # Personality modifiers (applied to move scores)
  PERSONALITY_MODIFIERS = {
    :aggressive => {
      :setup_moves       => 40,
      :powerful_moves    => 30,
      :risky_moves       => 25,
      :recoil_moves      => 15,
      :defensive_moves   => -30
    },
    :defensive => {
      :hazards           => 50,
      :screens           => 45,
      :recovery          => 40,
      :protect           => 35,
      :status_moves      => 30,
      :toxic_stall       => 20
    },
    :balanced => {
      :safe_setup        => 20,
      :recovery_low_hp   => 15,
      :finish_weak       => 10,
      :risky_moves       => -5
    },
    :hyper_offensive => {
      :damage_moves      => 60,
      :priority_moves    => 40,
      :multi_target      => 35,
      :super_effective   => 30,
      :status_moves      => -50,
      :switching         => -60
    }
  }
  
  # ============================================================================
  # AI BEHAVIOR SETTINGS
  # ============================================================================
  
  # If true, the AI will respect the "ReserveLastPokemon" flag on trainers
  # preventing their ace (last Pokemon) from being switched in early
  RESPECT_RESERVE_LAST_POKEMON = true
  
  # ============================================================================
  # COMPATIBILITY SETTINGS
  # ============================================================================
  
  # DBK Plugin Integration
  DBK_PLUGINS = {
    :mega_evolution   => true,  # Core Essentials (Enhanced)
    :dynamax          => true,  # DBK_005 - Dynamax
    :terastallization => true,  # DBK_006 - Terastallization
    :z_moves          => true,  # DBK_004 - Z-Power
    :raid_battles     => true,  # DBK_003 - Raid Battles
    :sos_battles      => true   # DBK_002 - SOS Battles
  }
  
  # Generation 9 Pack compatibility
  GEN9_PACK_COMPAT = true
  
  # ============================================================================
  # HELPER METHODS
  # ============================================================================
  
  # Check if Advanced AI is active
  def self.active?
    return false unless ENABLED
    return true if defined?(Settings::CHALLENGE_MODE) && Settings::CHALLENGE_MODE && ACTIVATE_WITH_CHALLENGE_MODES
    return @manually_activated || false
  end
  
  # Manually activate/deactivate
  def self.activate!
    @manually_activated = true
  end
  
  def self.deactivate!
    @manually_activated = false
  end
  
  # Check if skill level qualifies for Advanced AI
  # NOTE: This checks if ANY Advanced AI features are available (core threshold: 50)
  # MIN_SKILL_FOR_AUTO_ACTIVATION (70) is only for automatic activation
  def self.qualifies_for_advanced_ai?(skill_level)
    return false unless ENABLED  # System must be enabled
    return skill_level >= SKILL_THRESHOLDS[:core]  # Need at least core features (50+)
  end
  
  # Game Variable ID that controls the AI Mode globally
  # 0 = Disabled (Use Skill Level logic)
  # 1 = Force Beginner Mode
  # 2 = Force Mid Mode
  # 3 = Force Pro Mode
  AI_MODE_VARIABLE = 100
  
  # Get AI mode based on skill level (simplified to 3 tiers)
  def self.get_ai_tier(skill_level)
    # Check global variable override
    if defined?($game_variables)
      override = $game_variables[AI_MODE_VARIABLE]
      return :beginner if override == 1
      return :mid      if override == 2
      return :pro      if override == 3
    end
    
    # Fallback to skill-based logic
    return :beginner if skill_level <= 60
    return :mid if skill_level <= 85
    return :pro  # 86+
  end
  
  # Check if feature is enabled for skill level
  # NOTE: This checks if a specific feature is enabled based on skill threshold
  # Does NOT require active? (that's only for global system activation)
  def self.feature_enabled?(feature, skill_level)
    return false unless ENABLED  # System must be globally enabled
    return false unless SKILL_THRESHOLDS[feature]  # Feature must exist
    return skill_level >= SKILL_THRESHOLDS[feature]  # Check skill threshold
  end
  
  # Get setting value (with fallback)
  def self.get_setting(key, default = 0)
    return ADVANCED_FLAGS[key] || default
  end
  
  # Check if DBK plugin is enabled
  def self.dbk_enabled?(plugin)
    return false unless DBK_PLUGINS[plugin]
    
    # 1. Try PluginManager check (most reliable)
    if defined?(PluginManager) && PluginManager.respond_to?(:installed?)
      plugin_id = case plugin
        when :dynamax           then "DBK_005"
        when :terastallization  then "DBK_006"
        when :z_moves           then "DBK_004"
        when :raid_battles      then "DBK_003"
        when :sos_battles       then "DBK_002"
        else nil
      end
      return true if plugin_id && PluginManager.installed?(plugin_id)
    end
    
    # 2. Fallback to constant checks
    case plugin
    when :mega_evolution
      return true # Built-in to Essentials, always available if item held
    when :dynamax
      return defined?(Battle::Scene::USE_DYNAMAX_GRAPHICS)
    when :terastallization
      return defined?(Settings::TERASTALLIZE_TRIGGER_KEY)
    when :z_moves
      return defined?(Settings::ZMOVE_TRIGGER_KEY)
    when :raid_battles
      return defined?(Battle::RAID_MECHANICS)
    when :sos_battles
      return defined?(Battle::SOS_MECHANICS)
    else
      return false
    end
  end
  
  # Debug logging
  def self.log(message, category = "AI")
    return unless DEBUG_MODE
    Console.echo_li("[#{category}] #{message}")
  end
end

#===============================================================================
# Battle Integration
#===============================================================================

class Battle
  attr_accessor :advanced_ai_active
  attr_accessor :trainer_personalities
  
  alias aai_initialize initialize
  def initialize(*args)
    aai_initialize(*args)
    @advanced_ai_active = false
    @trainer_personalities = {}
  end
  
  # Check if trainer uses Advanced AI
  def uses_advanced_ai?(trainer_index)
    return false unless AdvancedAI.active?
    return false unless trainer_index
    trainer = pbGetOwnerFromBattlerIndex(trainer_index)
    return false unless trainer
    skill = trainer.skill_level || 50
    return AdvancedAI.qualifies_for_advanced_ai?(skill)
  end
  
  # Get/Set trainer personality
  def get_trainer_personality(trainer_index)
    @trainer_personalities[trainer_index] ||= detect_personality(trainer_index)
  end
  
  def set_trainer_personality(trainer_index, personality)
    @trainer_personalities[trainer_index] = personality
    AdvancedAI.log("Trainer #{trainer_index} personality set to #{personality}", "Personality")
  end
  
  private
  
  def detect_personality(trainer_index)
    return :balanced unless AdvancedAI::AUTO_DETECT_PERSONALITY
    # Will be implemented in Battle_Personalities.rb
    return :balanced
  end
end

#===============================================================================
# Skill Level Enhancement
#===============================================================================

class Battle::Battler
  # Enhanced skill level with AI tier
  def ai_skill_level
    return 0 unless @battle.opposes?(@index)
    trainer = @battle.pbGetOwnerFromBattlerIndex(@index)
    return 50 unless trainer
    return trainer.skill_level || 50
  end
  
  def ai_tier
    return AdvancedAI.get_ai_tier(ai_skill_level)
  end
end

#===============================================================================
# Challenge Mode Integration (Optional)
#===============================================================================

if defined?(Settings::CHALLENGE_MODE)
  EventHandlers.add(:on_start_battle, :advanced_ai_challenge_mode,
    proc { |battle|
      if Settings::CHALLENGE_MODE && AdvancedAI::ACTIVATE_WITH_CHALLENGE_MODES
        battle.advanced_ai_active = true
        AdvancedAI.log("Advanced AI activated via Challenge Mode", "Core")
      end
    }
  )
end

AdvancedAI.log("Advanced AI System v3.0.0 loaded successfully!", "Core")
