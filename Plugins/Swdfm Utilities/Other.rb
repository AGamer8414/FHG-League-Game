#=============================================================================
# Swdfm Utilites - Other
# 2025-03-18
#=============================================================================
module Swd
    module_function
    
#-------------------------------
    # Gets percentage based on numerator and denominator
    def get_percentage(num, denom)
        num * 100.0 / denom
    end
    
#-------------------------------
# Inserts Hash, with values of Integers.
# Returns the key that corresponds to the right number
    def weighted_hash(hash, amount = nil)
        hash.map { |key, count| [key] * count }.flatten.sample(amount)
    end
    
#-------------------------------
# Colours Hash
    COLOURS_HASH = {
        # Grayscale
        :COOL_BLACK => [57, 69, 81],
        :BLACK => [0, 0, 0],
        :DARK_GRAY => [63, 63, 63],
        :GRAY => [127, 127, 127],
        :LIGHT_GRAY => [191, 191, 191],
        :WHITE => [255, 255, 255],
        :COOL_WHITE => [206, 206, 206],
        # Reds
        :RED => [255, 0, 0],
        :COOL_RED => [255, 63, 63],
        :PASTEL_RED => [255, 127, 127],
        :PINK => [255, 191, 191],
        :ROSE => [255, 0, 110],
        :COOL_ROSE => [255, 63, 146],
        :PASTEL_ROSE => [255, 127, 182],
        :SKIN_TONE => [255, 191, 218],
        :BURGUNDY => [127, 0, 0],
        # Oranges/Browns
        :ORANGE => [255, 106, 0],
        :COOL_ORANGE => [255, 140, 63],
        :PASTEL_ORANGE => [255, 178, 127],
        :PEACH => [255, 216, 191],
        :BROWN => [127, 51, 0],
        :COOL_BROWN => [124, 68, 31],
        :PASTEL_BROWN => [124, 87, 62],
        :MUD => [124, 106, 93],
        # Yellow
        :YELLOW => [255, 216, 0],
        :COOL_YELLOW => [255, 223, 63],
        :PASTEL_YELLOW => [255, 233, 127],
        :APRICOT => [255, 244, 191],
        # Greens
        :GREEN => [0, 127, 0],
        :COOL_GREEN => [31, 124, 40],
        :SPRUCE => [62, 124, 68],
        :DEEP_SPRUCE => [93, 124, 96],
        :LIME_GREEN => [182, 255, 0],
        :PASTEL_LIME => [218, 255, 127],
        :LIGHT_GREEN => [0, 255, 0],
        :PASTEL_GREEN => [165, 255, 127],
        # Teals/Cyans
        :TEAL => [0, 255, 124],
        :COOL_TEAL => [ 63, 255, 168],
        :PASTEL_TEAL => [127, 255, 197],
        :SNOW => [191, 255, 226],
        :CYAN => [0, 255, 255],
        :COOL_CYAN => [63, 255, 255],
        :PASTEL_CYAN => [127, 255, 255],
        :ICE => [191, 255, 255],
        # Blues
        :MARINE => [0, 148, 255],
        :COOL_MARINE => [63, 175, 255],
        :PASTEL_MARINE => [127, 201, 255],
        :CLOUD => [191, 228, 255],
        :BLUE => [0, 0, 255],
        :COOL_BLUE => [63, 63, 255],
        :PASTEL_BLUE => [127, 127, 255],
        :LAVENDER => [191, 191, 255],
        :INDIGO => [72, 0, 255],
        :COOL_INDIGO => [114, 63, 255],
        :PASTEL_INDIGO => [161, 127, 255],
        :LILAC => [207, 191, 255],
        # Purples
        :PURPLE => [178, 0, 255],
        :COOL_PURPLE => [194, 63, 255],
        :PASTEL_PURPLE => [214, 127, 255],
        :BURDOCK => [234, 191, 255],
        :MAGENTA => [255, 0, 255],
        :COOL_MAGENTA => [255, 63, 255],
        :PASTEL_MAGENTA => [255, 127, 255],
        :PUCE => [204, 136, 153]
        # Custom
    }
    
#-------------------------------
# Inputs a symbol, outputs the colour object
    def get_colour(symbol, opacity = 255)
        col = COLOURS_HASH[symbol.upcase] || COLOURS_HASH[:BLACK]
        
        Color.new(*col, opacity)
    end
    
#-------------------------------
# eg. "one/two/three.txt" => ["one/two/", "three.txt"]
# Used for Bitmaps
    def split_file(file)
        unless file.ends_with?("/") || file.ends_with?(".png")
            file += ".png"
        end
        
        p, f = file.split_single("/")
        
        [p + "/", f]
    end
end

#-------------------------------
# Allows you to use eval without risking the game crashing
def secure_eval(code, return_if_fail = nil)
    return eval(code) if eval("defined?(#{code})")
    
    return_if_fail
end

#-------------------------------
# Returns the correct case of the constant in a mod
# If no const defined, returns nil
def const_defined_nocase?(mod, const_name)
    for const in mod.constants
        return const.to_s if const.to_s.casecmp(const_name.to_s) == 0
    end
    
    nil
end

#-------------------------------
# Slight Utilities for Handler Hashes
class HandlerHash_Swd < HandlerHash
    def trigger_sect(id, s, *args)
        return nil unless self[id]
        
        handler = self[id][s]
        
        handler&.call(*args)
    end
end

#-------------------------------
# Useful!
def has_attr_accessor?(klass, attr)
    klass.respond_to?(attr) && klass.respond_to?(:"#{attr}=")
end

#-------------------------------
# Useful!
module Boolean; end

class TrueClass ; include Boolean ; end

class FalseClass ; include Boolean ; end