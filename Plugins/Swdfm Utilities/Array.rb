#=============================================================================
# Swdfm Utilites - Arrays
# 2025-03-17
#=============================================================================
class Array
#-------------------------------
# Internal only!
    def all_to_data_type(type)
        self.map{ |element|
            if element.is_a?(Array)
                next element.all_to_data_type(type)
            end
            
            case type
            when "string"
                element.to_s
                
            when "symbol"
                element.to_sym
                
            when "integer"
                element.to_i
                
            else
                element
            end
        }
    end

#-------------------------------
# eg. ["a", "bunch", "of", "strings"] => [:a, :bunch, :of, :strings]
    def all_to_sym
        all_to_data_type("symbol")
    end
    
#-------------------------------
# eg. [:a, :bunch, :of, :strings] => ["a", "bunch", "of", "strings"]
    def all_to_s
        all_to_data_type("string")
    end
    
#-------------------------------
# eg. ["1", "3", "5", "7"] => [1, 3, 5, 7]
    def all_to_i
        all_to_data_type("integer")
    end
    
#-------------------------------
# eg. :string => [:string]
    def to_array
        self
    end
    
#-------------------------------
# Pushes item unless it's already there!
    def push_unless_there(*args)
        for arg in args
            self.push(arg) unless self.include?(arg)
        end
    end
    
#-------------------------------
# eg. ["a", "b", "c"].make_into_list => "a, b and c"
    def make_into_list(join_string = nil, end_string = " and ")
        join_string = ", " unless join_string
        
        all_but_last = self[0...-1]
        last_element = self[-1]
        
        all_but_last.join(join_string) + end_string + last_element
    end
    
#-------------------------------
# Gets index of first element that is not itself in the array
    def get_first_fill
        return 0 if self.empty?
        
        for i in 0...self.length
            return i unless self.include?(i)
        end
        
        self.length
    end
  
#-------------------------------
# eg. [4, 6, 7, 8] -> [4, 6-8]
    def list_as_numbers
        active_line = ""
        ret = []
        active_range = [-2, -2] # start of range, check number
        
        self.all_to_i.each_with_index do |current_element, i|
            if i.last_of?(self) || (current_element > active_range[1] + 1)
                unless active_line.empty?
                    unless active_range[0] == current_element
                        active_line += "-#{prev}"
                    end
                    
                    ret.push(active_line)
                end
                
                active_line = current_element.to_s
                active_range[0] = current_element
            end
            
            active_range[1] = current_element
        end
        
        ret.join(", ")
    end
    
#-------------------------------
    def includes_one_of?(*args)
        for arg in args
            return true if self.include?(arg)
        end
        
        false
    end
end