# SP May 2005
#
# Frames As Data Objects

class FE
  attr_accessor :name, :span, :tags
end

class Frame

  @target # SalsaTigerXmlNode Array
  @name   # string
  @fes    # (ID list -> FEs) Array
  

  def get_target
    return @target
  end

  def get_name
    return @name
  end

  def get_fes
    return @fes
  end

  def to_s # output the TigerSALSA-XML representation of a frame
    rep = Array.new
    rep << "<frame name=\"#{@name}\" id=\"#{@s}#{@id}\">"
    rep << "<target>"
    @target.each {|target_node|
      rep << "<fenode idref=\"#{@s}#{target_node.id}\"/>"
    }
    rep << "</target>"
    fe_idx = 0
    # the FE IDs are constructed on the fly, so they don't usually correspond to the
    # "original" FEs; but that shouldn't matter for evaluation anyway.
    @fes.each_pair {|synnode_id_list,fe_obj|
      fe_idx +=1
      fe_id = @id+"_e#{fe_idx}"
      rep << "<fe name=\"#{fe_obj.name}\" id=\"#{@s}#{fe_id}\">"
      synnode_id_list.each {|synnode_id|
	rep << "<fenode idref=\"#{@s}#{synnode_id}\"/>"
      }
      rep << "</fe>"
    }
    rep << "</frame>"
    return rep.join("\n")
  end
  
  def initialize(name,   # String
		 targetArray, # SalsaTigerXMLNode array
		 fes,    # ID list -> FE Obj Hash
		 frame_id, # Frame ID (sentid_frameid)
                 add_s = false) # if add_s = true, add s to the front of all ids     
    @name = name
    @fes = fes
    @target = targetArray
    @id = frame_id
    if add_s
      @s = "s"
    else
      @s = ""
    end
  end
end

# like a Frame, but initialized from a FrameNode object

class FrameFromNode < Frame
  
  def initialize(framenode_obj,filename,sent_id) # SalsaTigerXML frame object
    @name = framenode_obj.name
    @fes = Hash.new
    @id = framenode_obj.id

    nonolist = Array.new # record overused spans

    # read target

    target_node = framenode_obj.target()
    
    @target = Array.new
    target_node.each_child{|targetnode_obj|
      @target << targetnode_obj
    }
    
    # read FE children by name (collects FEs with more than one instances)

    framenode_obj.each_fe_by_name{|fe_obj|
      
      fe_name = fe_obj.name()
      fe_id = fe_obj.id()
      fe_flags = fe_obj.flags() # array of flags (String array)
 
      # initialise fes
      fe_nodes = Array.new
      fe_obj.each_child{|fenode_obj|	  
        fe_nodes << fenode_obj
      }
      this_fe = FE.new
      this_fe.name = fe_name
      this_fe.span = fe_nodes
      this_fe.tags = fe_flags
      
      span = fe_nodes.map {|fe_node| fe_node.id}
      
      if @fes.key?(span)
        #	  if filename and sent_id
        puts "Warning: in file #{File.basename(filename)} sentence #{@id}, one span ([#{fe_nodes.join(" ")}]) is covered by several FEs. Ignoring this span."
        #	  else
        #	    puts "Warning: one span ([#{fe_nodes.join(" ")}]) is covered by several FEs . Ignoring this span."
        #	  end
        nonolist << span
      end
      @fes[span] = this_fe	
    }
    nonolist.each {|span|
      @fes.delete(span)
    }
  end
end
