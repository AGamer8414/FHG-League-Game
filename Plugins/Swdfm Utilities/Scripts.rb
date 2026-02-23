#=============================================================================
# Swdfm Utilites - Scripts
# 2025-03-18
#=============================================================================
module Swd
    module_function
    
#-------------------------------
# Writes all Scripts or Plugins in one big .txt file
    def write_all_code(type = "plugins")
        doing_scripts = type == "scripts"
        
        path = "Outputs/"
        scripts = nil
        
        Dir.mkdir(path) rescue nil
        
        if doing_scripts
            File.open("Data/Scripts.rxdata") do |file|
                scripts = Marshal.load(file)
            end
            
            output_file = "#{path}scripts_full.txt"
            heading = "# Script Page: "
        else
            scripts = load_data("Data/PluginScripts.rxdata")
            output_file = "#{path}plugins_full.txt"
            heading = "# Plugin Page: "
        end
        
        this_proc = proc { |file, page_name, script_contents, folder_name|
            file.write("#{self.bigline}\n")
            
            if doing_scripts
                page_name = "#{page_name}\n"
            else
                page_name = "#{folder_name}/#{page_name}\n"
            end
            
            file.write(heading + page_name)
            file.write("#{self.bigline}\n")
            
            scr = Zlib::Inflate.inflate(script_contents).force_encoding(Encoding::UTF_8)
            
            file.write("#{scr.gsub("\t", "    ")}\n")
        }
        
        File.open(output_file, "wb") { |f|
            for script in scripts
                if doing_scripts
                    this_proc.call(f, script[1], script[2], nil)
                else
                    for script_int in script[2]
                        this_proc.call(f, script_int[0], script_int[1], script[0])
                    end
                end
            end
        }
        
    end
    
#-------------------------------
# Writes all RPG Maker XP Scripts in one big .txt file
    def write_all_scripts
        write_all_code("scripts")
    end
    
#-------------------------------
# Writes All Plugins in one big .txt file
    def write_all_plugins
        write_all_code
    end

#-------------------------------
    def pbsline
        "#-------------------------------"
    end

#-------------------------------
    def bigline
        "#==============================================================================="
    end
  
#-------------------------------
    def replace_scripts(hash, insert_hash = {})
        return unless $DEBUG
        
        scripts = nil
        
        File.open("Data/Scripts.rxdata") do |file|
            scripts = Marshal.load(file)
        end
        
        File.open("Data/Scripts_Spare.rxdata", "wb") { |f|
            Marshal.dump(scripts, f)
        }
        
        for script in scripts
            code = Zlib::Inflate.inflate(script[2]).force_encoding(Encoding::UTF_8)
            
            for data in hash
                code.gsub!(*data)
            end
            
            for k, v in insert_hash
                next if code.include?(v)
                code.gsub!(k, v)
            end
        
            script[2] = Zlib::Deflate.deflate(code) #, Zlib::FINISH)
        end
        
        # Save the script!
        File.open("Data/Scripts.rxdata", "wb") { |f|
            Marshal.dump(scripts, f)
        }
    
        echoln "Scripts have all been replaced!"
    end
    
#-------------------------------
    def open_plugins(state = :neaten, param = nil)
        plugin_scripts = load_data("Data/PluginScripts.rxdata")
        
        plugin_hash = {}
        
        for p, v in PluginManager.getPluginOrder[1]
            plugin_hash[v[:name]] = v[:dir]
        end
        
        plugin_scripts.each do |plugin|
            plugin[2].each do |script|
                path = plugin_hash[plugin[0]].to_s + "/" + script[0].to_s
                
                File.open(path, "wb") { |f|
                    scr = Zlib::Inflate.inflate(script[1]).force_encoding(Encoding::UTF_8)
                    
                    case state
                    when :neaten
                        scr.gsub!("\r\n", "\n")
                        scr.gsub!("\t", "    ")
                        
                    when :replace
                        param.keys.sort!{ |b, a|
                            a.length <=> b.length
                        }
                        
                        for k, v in param
                            scr.gsub!(k, v)
                        end
                    end
                    
                    f.write(scr.to_s)
                }
            end
        end
    end
    
#-------------------------------
    def neaten_plugins
        open_plugins
    end
    
#-------------------------------
    def replace_plugins(hash)
        open_plugins(:replace, hash)
    end
end