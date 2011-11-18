# sp 04 05
#
# easier access to the frame information present in a SalsaTigerSentence:
# 
# FrameHashObj provides a hash   Target (as set of node IDs) ->  FrameObj
# FrameObj provides a hash       Span (as set of node IDs) -> FE (by name)

require "Frame"

module FrameHash

  def get_frame_hash
    return @frame_hash
  end
  
  def compute_frame_hash(filename=nil)
    # you can specify filename for more verbose error msg, if available
    @frame_hash = Hash.new

    nonolist = Array.new # record overused targets
    
    self.each_frame {|rexml_frame|
      frame = FrameFromNode.new(rexml_frame,filename,id)
      target = frame.get_target.map {|target_node| target_node.id}
      if @frame_hash.key?(target) 
	if filename
	  puts "Warning: in file #{File.basename(filename)} sentence #{id}, one target ([#{frame.get_target.join(" ")}]) evokes several frames . Ignoring this target."
	else
	  puts "Warning: in sentence #{id}, one target ([#{frame.get_target.join(" ")}]) evokes several frames . Ignoring this target."
	end
	nonolist << target
      end
      @frame_hash[target] = frame
    }
    nonolist.each {|target|
      @frame_hash.delete(target)
    }
  end
  
end
