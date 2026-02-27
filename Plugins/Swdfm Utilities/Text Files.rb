#=============================================================================
# Swdfm Utilites - Text Files
# 2025-03-18
#=============================================================================
module Swd
    module_function
    
#-------------------------------
# Ignores new lines, and any line with first significant character of "#"
    def format_line(line, flags = [])
        for strs in [["\r", ""], ["\n", ""], ["\t", "    "]]
            line.gsub!(*strs)
        end
        
        line = line.before_first("#") if flags.include?(:STRICT)
        
        return line if line.empty?
        
        flags.include?(:SANDWICH) ? line.strip : line
    end
    
#-------------------------------
# Reads all text in a .txt file
    def read_txt(path)
        path += ".txt" unless path.ends_with?(".txt")
        
        File.readlines(path)
    end
    
#-------------------------------
# Reads all text in a .txt file
    def read_txt_neat(path, strict = false)
        lines = read_txt(path)
        flags = strict ? [:STRICT, :SANDWICH] : [:SANDWICH]
        
        lines.map{ |line|
            f_line = format_line(line, flags)
            
            (f_line.empty? || f_line.unblanked.starts_with?("#")) ? nil : f_line
        }.compact
    end
    
#-------------------------------
# Reads all text in a PBS .txt file
    def read_pbs(path)
        path = "PBS/" + path unless path.starts_with?("PBS/")
        
        read_txt(path)
    end
    
#-------------------------------
    def read_pbs_neat(path, strict = false)
        path = "PBS/" + path unless path.starts_with?("PBS/")
        
        read_txt_neat(path, strict)
    end
    
#-------------------------------
# Clears a text file. Makes one if needed.
    def clear_txt_file(file)
        file += ".txt" unless file.ends_with?(".txt")
        
        File.open(file, "wb") { |f|
            f.write("")
        }
    end
    
#-------------------------------
# Writes a line and appends it to a file
    def write_line(line, file)
        file += ".txt" unless file.ends_with?(".txt")
        
        File.open(file, "ab") { |f|
            f.write(line + "\r\n")
        }
    end
    
#-------------------------------
# Gets an array and dumps it in a .txt file
    def dump_txt(lines, file, type = "wb")
        file += ".txt" unless file.ends_with?(".txt")
        
        self.clear_txt_file(file) if type == "wb"
        
        File.open(file, type) { |f|
            for line in lines
                f.write(line + "\n")
            end
        }
    end
    
#-------------------------------
    def lines
        read_txt("infile")
    end
    
#-------------------------------
    def dump(t)
        dump_txt(t, "outfile")
    end
end