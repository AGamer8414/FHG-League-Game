#=============================================================================
# Swdfm Utilites - String
# 2025-03-18
#=============================================================================
class String
    
#-------------------------------
# eg. "firstpart".starts_with?("first") => => true
#     "firstpart".starts_with?("part") => => false
    def starts_with?(sub_str)
        sub_str.length > self.length ? false : self[0, sub_str.length] == sub_str
    end
    
#-------------------------------
# eg. "firstpart".ends_with?("first") => => false
#     "firstpart".ends_with?("part") => => true
    def ends_with?(sub_str)
        sub_str.length > self.length ? false : self[-sub_str.length, sub_str.length] == sub_str
    end
    
#-------------------------------
# eg. "let me in" => "letmein"
    def unblanked
        self.gsub(" ", "")
    end
    
#-------------------------------
# eg. "    s p a c e    " => "s p a c e"
    def sandwich
        self.strip
    end
    
#-------------------------------
# eg. "before first".before_first(" ") => "before"
    def before_first(sub_str)
        index = self.index(sub_str)
        
        index ? self[0, index] : self
    end
    
#-------------------------------
# "after first one".after_first(" ") => "first one"
    def after_first(sub_str)
        index = self.index(sub_str)
        
        return "" unless index
        
        index += sub_str.length
        
        self[index, self.length - index]
    end
    
#-------------------------------
# eg. "the one before last".before_last(" ") => "the one before"
    def before_last(sub_str)
        index = self.rindex(sub_str)
        
        index ? self[0, index] : self
    end
    
#-------------------------------
# eg. "the one after last".after_last(" ") => "last"
    def after_last(sub_str)
        index = self.rindex(sub_str)
        
        return "" unless index
        
        index += sub_str.length
        
        self[index, self.length - index]
    end
    
#-------------------------------
# eg. "pre_post".u_split => ["pre", "post"]
    def u_split
        self.split("_")
    end
    
#-------------------------------
# eg. "pre__post".w_split => ["pre", "post"]
    def w_split
        self.split("__")
    end
    
#-------------------------------
# eg. "string" => ["string"]
    def to_array
        [self]
    end
    
#-------------------------------
# eg. "foobar" => "Foobar"
    def first_cap
        self.gsub("_", " ").split(" ").map!{ |element|
            first_cap_internal(element)
        }.join(" ")
    end
    
#-------------------------------
    def first_cap_internal(str)
        str[0, 1].upcase + str[1, str.length - 1].downcase
    end
    
#-------------------------------
# eg. "[foobar]".multi_delete("[", "]") => "foobar"
    def multi_delete(*args)
        ret = self
        
        for arg in args
            ret.gsub!(arg, "")
        end
        
        ret
    end
  
#-------------------------------
    def is_all_numbers?
        self.chars.all?{ |char| "0123456789_".include?(char) }
    end
    
#-------------------------------
    def starts_with_number?
        char = self[0, 1]
        
        char.is_all_numbers? && char != "_"
    end
    
#-------------------------------
# Removes all punctuation from a string (except spaces)
    def remove_puncts
        accepted = "abcdefghijklmnopqrstuvwxyz"
        
        accepted += accepted.upcase + "1234567890_"
        
        self.chars.map{ |char|
            accepted.include?(char) ? (char == "é" ? e : char) : nil
        }.compact.join
    end
    
#-------------------------------
    def palindrome?
        self.chars.each_with_index do |char, i|
            quiv_char = self.chars[-1 - i]
            
            return false unless char == quiv_char
            
            return true if i + 1 >= self.length / 2.0
        end
        
        false # FS!
    end
    
#-------------------------------
    def lhs(splitter = "_")
        self.split(splitter)[0]
    end

#-------------------------------
    def mhs(splitter = "_")
        self.split(splitter)[1] || ""
    end
    
#-------------------------------
    def rhs(splitter = "_")
        return "" unless self.include?(splitter)
        
        self.split(splitter)[-1]
    end

#-------------------------------
    def a
        self.starts_with_vowel? ? _INTL("an") : _INTL("a")
    end
    
#-------------------------------
    def s
        self.ends_with?("s") ? _INTL("{1}'", self) : _INTL("{1}'s", self)
    end
    
#-------------------------------
    def count_amount(sub_str)
        self.scan(sub_str).size
    end
    
#-------------------------------
# Skewed alphanumeric affine cipher
# Not sure what it specifically does
    def to_alphabet_int
        ret = 0
        strs = [
            "8NFH", "UIVJ", "2AQZ",
            "0TKM", "PRXE", "O79G",
            "B5CD", "S41L", "63WY"
        ]
        
        self.chars.each_with_index do |c, s|
            strs.each_with_index do |ss, i|
                next unless ss.include?(c)
                
                ret += i * (strs.length ** s)
                
                break
            end
        end
        
        ret
    end

#-------------------------------
# splits a square, but ignores any text between any brackets
# eg. "sdsd, sdsds(sdsd, sdsds)" => ["sdsd", sdsds(sdsd, sdsds)"]
    def split_non_bracket(splitter = ",", with_sandwich = true)
        bc_level = 0
        bs_level = 0
        active_word = ""
        ret = []
        
        for c in self.chars
            case c
            when "("
                bc_level += 1
                
            when "["
                bs_level += 1
                
            when ")"
                bc_level -= 1
                
            when "]"
                bs_level -= 1
            end
            
            active_word += c
            
            next if bc_level > 0 || bs_level > 0
            
            if active_word.ends_with?(splitter)
                to_push = active_word[..-splitter.length - 1]
                
                to_push.strip! if with_sandwich
                
                ret.push(to_push)
                
                active_word = ""
            end
        end
        
        unless active_word == ""
            to_push = active_word
            
            to_push.strip! if with_sandwich
            
            ret.push(to_push)
        end
        
        ret
    end
    
#-------------------------------
    def is_definitely_float?
        return false unless self.include?(".")
        
        begin
            original_stderr = $stderr
            $stderr = File.open(File::NULL, "w")
            
            Float(self)
            
            return true
        rescue
            return false
        ensure
            $stderr = original_stderr
        end
    end
    
#-------------------------------
    def split_stray_bracket(which = "(")
        ret = ""
        
        case which
        when "(" then oppo = ")"
        when ")" then oppo = "("
        when "[" then oppo = "]"
        when "]" then oppo = "["
        end
        
        count_which = 0
        last_stray_index = nil
        
        self.chars.each_with_index do |c, i|
            count_which += 1 if c == which
            count_which -= 1 if c == oppo
            
            # If we have one extra opening bracket, track its position
            last_stray_index = i if count_which == 1 && c == which
        end
        
        return [self, ""] unless last_stray_index # No stray bracket found
        
        [self[0...last_stray_index], self[last_stray_index + 1..-1]]
    end
    
#-------------------------------
    def starts_with_one_of?(*sub_strs)
        sub_strs = sub_strs[0] if sub_strs[0].is_a?(Array)
        
        !!sub_strs.find{ |sub_str| self.starts_with?(sub_str)} # Correct!
    end
    
#-------------------------------
    def includes_one_of?(*sub_strs)
        sub_strs = sub_strs[0] if sub_strs[0].is_a?(Array)
        
        !!sub_strs.find{ |sub_str| self.include?(sub_str)} # Correct!
    end
    
#-------------------------------
    def ends_with_one_of?(*sub_strs)
        sub_strs = sub_strs[0] if sub_strs[0].is_a?(Array)
        
        !!sub_strs.find{ |sub_str| self.ends_with?(sub_str)} # Correct!
    end
    
#-------------------------------
    def split_single(sub_str = "_", do_last = false)
        return [self.before_last(sub_str), self.after_last(sub_str)] if do_last
        
        [self.before_first(sub_str), self.after_first(sub_str)]
    end
    
#-------------------------------
# eg. "Hello there" -> "HELLO_THERE"
    def to_const
        self.gsub(" ", "_").upcase
    end
end