#=============================================================================
# Text Replacement
# By Swdfm
# As part of Modular Messages Pack
# Updated 2025-04-25
#=============================================================================
# Methods dealing with text formatting
# Order of run methods is important!
# Be careful modifying, as some lines important!
#-------------------------------
module Modular_Messages
    module_function
    
#-------------------------------
# Main Text Replacement Function
    def replace_text
        replace_initial
        replace_game_data # new!
        replace_scripts # new!
        replace_player_name
        replace_player_money
        
        # \n
        @@hash["text"].gsub!(/\\n/i, "\n")
        
        replace_colours_direct
        replace_player_gender
        replace_windowskin
        replace_colours_id
        replace_variables
        replace_lines
        replace_colours_final
    end
    
#-------------------------------
# Initial Text Replacement Method
    def replace_initial
        # \sign[something] gets turned into
        
        @@hash["text"].gsub!(/\\sign\[([^\]]*)\]/i) do
            # \op\cl\ts[]\w[something]
            next "\\op\\cl\\ts[]\\w[" + $1 + "]"
        end
        
        @@hash["text"].gsub!(/\\\\/, "\5")
        @@hash["text"].gsub!(/\\1/, "\1")
        
        if $game_actors
            @@hash["text"].gsub!(/\\n\[([1-8])\]/i) { next $game_actors[$1.to_i].name }
        end
    end
    
#-------------------------------
# Player Name
    def replace_player_name
        @@hash["text"].gsub!(/\\pn/i, $player.name) if $player
    end
    
#-------------------------------
# Player Money
    def replace_player_money
        @@hash["text"].gsub!(/\\pm/i, _INTL("${1}", $player.money.to_s_formatted)) if $player
    end
    
#-------------------------------
# Specific colours
    def replace_colours_direct
        @@hash["text"].gsub!(/\\\[([0-9a-f]{8,8})\]/i) { "<c2=" + $1 + ">" }
    end
    
#-------------------------------
# Player Gender
# \pg, \pog, \b, \r
    def replace_player_gender
        @@hash["text"].gsub!(/\\pg/i, "\\b") if $player&.male?
        @@hash["text"].gsub!(/\\pg/i, "\\r") if $player&.female?
        @@hash["text"].gsub!(/\\pog/i, "\\r") if $player&.male?
        @@hash["text"].gsub!(/\\pog/i, "\\b") if $player&.female?
        @@hash["text"].gsub!(/\\pg/i, "")
        @@hash["text"].gsub!(/\\pog/i, "")
        
        male_text_tag = shadowc3tag(MessageConfig::MALE_TEXT_MAIN_COLOR, MessageConfig::MALE_TEXT_SHADOW_COLOR)
        female_text_tag = shadowc3tag(MessageConfig::FEMALE_TEXT_MAIN_COLOR, MessageConfig::FEMALE_TEXT_SHADOW_COLOR)
        
        @@hash["text"].gsub!(/\\b/i, male_text_tag)
        @@hash["text"].gsub!(/\\r/i, female_text_tag)
    end
    
#-------------------------------
# Windowskins
# \w[WINDOWSKIN_NAME]
    def replace_windowskin
        @@hash["text"].gsub!(/\\[Ww]\[([^\]]*)\]/) do
            w = $1.to_s
            
            if w == ""
                @@hash["msg_window"].windowskin = nil
            else
                @@hash["msg_window"].setSkin("Graphics/Windowskins/#{w}", false)
            end
            
            next ""
        end
    end
    
#-------------------------------
# \c[0]... etc.
    def replace_colours_id
        @@hash["text"].gsub!(/\\c\[([0-9]+)\]/i) do
            next getSkinColor(@@hash["msg_window"].windowskin, $1.to_i, @@hash["dark_skin"])
        end
    end
    
#-------------------------------
# Variables in @@hash["text"]
# \v[1] etc.
# new: Works with script constants
# \v[VARIABLE_CONSTANT]
# NOTE: Also works with constants within a module
    def replace_variables
        loop do
            last_text = @@hash["text"].clone
            
            @@hash["text"].gsub!(/\\[Vv]\[([^\]]*)\]/) do
                variable_name = $1.to_s
                variable = ""
                
                if variable_name.is_all_numbers?
                     variable = $game_variables[variable_name.to_i]
                else
                    if Object.const_defined?(variable_name) &&
                       eval(variable_name).is_a?(Integer)
                        variable = $game_variables[eval(variable_name)]
                    end
                end
                
                next variable.to_s
            end
            
            break if @@hash["text"] == last_text
        end
    end
    
#-------------------------------
# Scripts in Text!
# eg. \sc[$player.badge_count] -> "0"
# NOTE: Any script with [] in will not work!
# eg. \sc[$player.badges[0]] -> ERROR!
    def replace_scripts
        loop do
            last_text = @@hash["text"].clone
            
            @@hash["text"].gsub!(/\\sc\[([^\]]*)\]/i) do
                next secure_eval($1.to_s, "").to_s
            end
            
            break if @@hash["text"] == last_text
        end
    end
    
#-------------------------------
# GameData in Text!
    # eg. \species[castform] -> Castform
    # eg. \type[fire] -> Fire
    # eg. \itemplural[charcoal] -> Charcoals
    def replace_game_data
        loop do
            last_text = @@hash["text"].clone
            
            @@hash["text"].gsub!(/\\([a-zA-Z0-9_]+)\[([^\]]*)\]/) do
                lhs_init = $1.to_s
                rhs_init = $2.to_s
                
                lhs = lhs_init.downcase
                rhs = rhs_init.downcase
                
                cdn = const_defined_nocase?(GameData, lhs)
                
                if lhs.gsub("_", "").downcase.starts_with?("itemplural")
                    # Item Plurals
                    real_key = nil
                    for k in GameData::Item.keys
                        real_key = k if k.to_s.downcase == rhs
                    end
                    
                    if real_key && GameData::Item.exists?(real_key)
                        next GameData::Item.get(real_key).name_plural
                    end
                    
                    next ""
                    
                elsif cdn # eg. GameData::Type
                    gds = "GameData::#{cdn}"
                    
                    gd = eval(gds)
                    
                    if eval(gds + ".respond_to?(:get)")
                        # Gets real case of key
                        real_key = nil
                        
                        for k in gd.keys
                            real_key = k if k.to_s.downcase == rhs
                        end
                        
                        if real_key &&
                           eval(gds + ".exists?(:#{real_key})")
                            this_gds = eval(gds + ".get(:#{real_key})")
                            
                            if this_gds.respond_to?("name")
                                # Finally confirmed as existing!
                                next this_gds.name
                            end
                        end
                    end
                    
                    next ""
                end
                
                next "\\" + lhs_init + "[" + rhs_init + "]"
            end
            
            break if @@hash["text"] == last_text
        end
    end
    
#-------------------------------
# Sets number of lines of box
# eg. \l[5]
    def replace_lines
        loop do
            last_text = @@hash["text"].clone
            
            @@hash["text"].gsub!(/\\l\[([0-9]+)\]/i) do
                @@hash["line_count"] = [1, $1.to_i].max
                
                next ""
            end
            
            break if @@hash["text"] == last_text
        end
    end
    
#-------------------------------
# Chooses actual colour of message @@hash["text"]
    def replace_colours_final
        dark_skin = (
            $game_system && $game_system.message_frame != 0
        ) ? true : @@hash["dark_skin"]
        
        colourtag = getSkinColor(@@hash["msg_window"].windowskin, 0, dark_skin)
        
        @@hash["text"] = colourtag + @@hash["text"]
    end
end