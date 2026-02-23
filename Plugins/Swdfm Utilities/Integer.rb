#=============================================================================
# Swdfm Utilites - Integer
# 2025-03-18
#=============================================================================
class Integer
    
#-------------------------------
# eg. 1 => [1]
    def to_array
        [self]
    end
    
#-------------------------------
# eg. 1 => 1, 2 => 3, 3 => 6 etc.
    def triangle
        ret = (self ** 2).to_f / 2 + (self.to_f / 2)
        
        ret.to_i
    end
    
#-------------------------------
# eg. 100.midpoint(200) => 150
    def midpoint(other_int)
        min_int = [self, other_int].min
        max_int = [self, other_int].max
        
        min_int + (max_int - min_int) / 2
    end
  
#-------------------------------
    def quot(div)
        (self / div).floor
    end
    
#-------------------------------
    def rem(div)
        [quot(div), self % div]
    end
    
#-------------------------------
    def remove_rem(div)
        quot(div) * div
    end
    
#-------------------------------
    def last_of?(array)
        self == array.length - 1
    end
    
    alias is_last? last_of?
end

#=============================================================================
class Float
    def quot(div)
        (self / div).floor
    end
end