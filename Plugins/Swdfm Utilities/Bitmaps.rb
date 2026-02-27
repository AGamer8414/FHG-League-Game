#=============================================================================
# Swdfm Utilites - Bitmaps
# 2025-03-17
#=============================================================================
module Swd_Bitmap
    module_function
    
#-------------------------------
# Usually used for animated sprites with no foreground!
    def empty(w, h)
        Bitmap.new(w, h)
    end
    
#-------------------------------
# Gets the straight up bitmap from file
    def direct(file)
        RPG::Cache.load_bitmap(*Swd.split_file(file), 0)
    end
    
#-------------------------------
# Colours a bitmap with a defined colour in a defined space
    def colour(bmp, col, x, y, w, h)
        if !bmp
            bmp = self.empty(w, h)
        elsif bmp.is_a?(Array)
            bmp = self.empty(*bmp)
        end
        
        bmp.fill_rect(x, y, w, h, col)
    end
    
#-------------------------------
# Basically two lots of self.colour !
    def box(bmp, edge_col, fill_col, edge_size)
        bmp = self.empty(*bmp) if bmp.is_a?(Array)
        
        w = bmp.width
        h = bmp.height
        
        bmp.fill_rect(0, 0, w, h, edge_col)
        
        bmp.fill_rect(
            edge_size, edge_size, w - 2 * edge_size,
            h - 2 * edge_size, fill_col
        )
    end
    
#-------------------------------
# first and second are an array of 3 [r, g, b] or Color object
# segment_w and s_h stand for segment width/height
    def gradient(first, second, w, h, segment_w = nil, segment_h = nil, dir = :VERTICAL, bmp = nil)
        segment_w = 1 unless segment_w
        segment_h = 1 unless segment_h
        
        [first, second].map!{ |this_colour|
            if this_colour.is_a?(Color)
                this_colour = [
                    this_colour.red, this_colour.green,
                    this_colour.blue, this_colour.alpha
                ]
            elsif this_colour.length == 3
                this_colour.push(255)
            end
            
            this_colour
        }
        
        ret = bmp || self.empty(w, h)
        
        x = bmp ? (bmp.width - w) / 2 : 0
        y = bmp ? (bmp.height - h) / 2 : 0
        
        num_segments = dir == :VERTICAL ? h / segment_h : w / segment_w
        
        colour_data = []
        
        for j in 0...4
            colour_data.push([first[j], second[j] - first[j]])
        end
        
        for i in 0...num_segments
            colour = []
            
            for j in 0...4
                baseline, difference = colour_data[j]
                
                colour.push([baseline + i * difference.quot(num_segments), 255].min)
            end
            
            colour = Color.new(*colour)
            
            case dir
            when :VERTICAL
                ret.fill_rect(x, y + segment_h * i, w, segment_h, colour)
            else
                ret.fill_rect(x + segment_w * i, y, segment_w, h, colour)
            end
        end
        
        ret
    end
  
#-------------------------------
# Places Text On An Empty Bitmap
# align: 0 is left, 1 is right, 2 is centre
    def text(text, hash, bmp = nil, size = nil)
        w = hash[:W] || 32
        h = hash[:H] || w
        
        bmp = self.empty(w, h) unless bmp
        
        align = hash[:Align] || 0
        outline = hash[:Outline] || false
        gap = hash[:Gap] || 0
        anch = hash[:Anchor] || :C
        y_gap = hash[:Y_Gap] || 16
        base = hash[:Base] || rad_BASE
        shad = hash[:Shadow] || rad_SHADOW
        
        x = align == 2 ? bmp.width / 2 : gap
        y = 0
        y = bmp.height / 2 - y_gap / 2 if anch == :C
        x = hash[:X] if hash[:X]
        y = hash[:Y] if hash[:Y]
        
        pbSetSystemFont(bmp)
        
        bmp.font.size = size if size
        
        text_pos = [[text, x, y, align, base, shad, outline]]
        
        pbDrawTextPositions(bmp, text_pos)
        
        bmp
    end
  
#-------------------------------
# (Colour Object used for both)
# Replaces all pixels of one colour with another colour
    def replace_colours(bmp, to_replace, replace_with)
        w = bmp.width
        h = bmp.height
        
        for x in 0...w
            for y in 0...h
                # TODO rgb must be same, but not nece alpha
                next unless bmp.get_pixel(x, y) == to_replace
                
                a = bmp.get_pixel(x, y).alpha
                
                replace_with.alpha = a unless replace_with.alpha == 0
                
                bmp.fill_rect(x, y, 1, 1, replace_with)
            end
        end
        
        bmp
    end
    
#-------------------------------
# Takes a number of bitmaps, and makes them into one
    def assemble(bmp_array)
        biggest_x = 1
        biggest_y = 1
        
        dimensions = []
        
        # First, determine the size of the canvas
        for hash in bmp_array
            bmp = hash[:Bitmap]
            x = hash[:X] || 0
            y = hash[:Y] || 0
            
            dimensions.push([x, y, bmp, Rect.new(0, 0, bmp.width, bmp.height)])
            
            biggest_x = [biggest_x, x + bmp.width].max
            biggest_y = [biggest_y, y + bmp.height].max
        end
        
        ret = self.empty(biggest_x, biggest_y)
        
        # Now, add the actual bitmaps!
        for dims in dimensions
            ret.blt(*dims)
        end
        
        ret
    end
    
#-------------------------------
    def impose(bmp, w, h = nil, anchor = :C)
        h = w if h.nil?
        orig_w = bmp.width
        orig_h = bmp.height
        gap_w = w - orig_w
        gap_h = h - orig_h
        
        # Let's do Xs first!
        x = 0 # :NW, :W, :SW
        
        case anchor
        when :N,  :C, :S
            x = gap_w / 2
            
        when :NE, :E, :SE
            x = gap_w
        end
        
        # Now we'll do Ys!
        y = 0 # :NW, :N, :NE
        
        case anchor
        when :W,  :C, :E
            y = gap_h / 2
            
        when :SW, :S, :SE
            y = gap_h
        end
        
        self.empty(w, h).blt(x, y, bmp, Rect.new(0, 0, orig_w, orig_h))
    end
end

#=============================================================================
# Saves to PNG
#=============================================================================
class Bitmap
    def save_to_png(filename)
        f = ByteWriter.new(filename)
        
    #============================= Writing header ===============================#
        # PNG signature
        f << [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        
        # Header length
        f << [0x00, 0x00, 0x00, 0x0D]
        
        # IHDR
        headertype = [0x49, 0x48, 0x44, 0x52]
        
        f << headertype
        
        # Width, height, compression, filter, interlacing
        headerdata = ByteWriter.to_bytes(self.width).
          concat(ByteWriter.to_bytes(self.height)).
          concat([0x08, 0x06, 0x00, 0x00, 0x00])
        
        f << headerdata
        
        # CRC32 checksum
        sum = headertype.concat(headerdata)
        
        f.write_int Zlib::crc32(sum.pack("C*"))
        
    #============================== Writing data ================================#
        data = []
        
        for y in 0...self.height
            # Start scanline
            data << 0x00 # Filter: None
            
            for x in 0...self.width
                px = self.get_pixel(x, y)
                
                # Write raw RGBA pixels
                data << px.red
                data << px.green
                data << px.blue
                data << px.alpha
            end
        end
        
        # Zlib deflation
        smoldata = Zlib::Deflate.deflate(data.pack("C*")).bytes
        
        # data chunk length
        f.write_int smoldata.size
        
        # IDAT
        f << [0x49, 0x44, 0x41, 0x54]
        f << smoldata
        
        # CRC32 checksum
        f.write_int Zlib::crc32([0x49, 0x44, 0x41, 0x54].concat(smoldata).pack("C*"))
    
    #============================== End Of File =================================#
        # Empty chunk
        f << [0x00, 0x00, 0x00, 0x00]
        
        # IEND
        f << [0x49, 0x45, 0x4E, 0x44]
        
        # CRC32 checksum
        f.write_int Zlib::crc32([0x49, 0x45, 0x4E, 0x44].pack("C*"))
        f.close
        
        nil
    end
end

class ByteWriter
    def initialize(filename)
        @file = File.new(filename, "wb")
    end
    
    def <<(*data)
        write(*data)
    end
    
    def write(*data)
        data.each do |e|
            if e.is_a?(Array) || e.is_a?(Enumerator)
                e.each { |item| write(item) }
            elsif e.is_a?(Numeric)
                @file.putc e
            else
                raise "Invalid data for writing.\nData type: #{e.class}\nData: #{e.inspect[0..100]}"
            end
        end
    end
 
    def write_int(int)
        self << ByteWriter.to_bytes(int)
    end
 
    def close
        @file.close
        @file = nil
    end
 
    def self.to_bytes(int)
        [
            (int >> 24) & 0xFF,
            (int >> 16) & 0xFF,
            (int >> 8) & 0xFF,
            int & 0xFF
        ]
    end
end