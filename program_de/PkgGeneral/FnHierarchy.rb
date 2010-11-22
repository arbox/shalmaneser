# FNHierarchy
# KE March 2004
#
# provides class FramesAndRelations
# which reads the FN frame relations into a graph
# and manages the graph.
#
# initialization: with an XML file, the file frames.xml
#
# augmenting with frame relations: method add_relations, parameter is the file frRelations.xml
#
# Graph nodes are as defined in Graph.rb
# Frame names are used as IDs for frame graph nodes.
# For FEs, the IDs have the form "Frame_name FE_name" with a space inbetween. 
# 
# access methods:
#
# frames() returns a list of all frames as graph nodes
# fes() returns a list of all frame elements as graph nodes
# get_frame(name) returns the graph node for that frame
# get_fe(frame_name, fe_name) returns the graph node for that FE.
# add_frame_relation(relation, frame1, frame2) adds a link named by this relation btw 
#        the frames with names frame1 and frame2
# add_fe_relation(relation, fename1, framename1, fename2, framename2) adds a link named
#        by this relation between these FEs of these frames.

require "Graph"
require "rexml/document"
include REXML


###########################################

class FrameNode < GraphNode

  def FrameNode._load(string)
    id, features_s, children_s, parents_s =
      string.split("QQSEPVALUESQQ")

    result = FrameNode.new(id)
    result.fill_from_pickle(string)
    return result
  end

  def initialize(frame_name)
    super(frame_name)
    set_f("name", frame_name)
  end

  def add_fe(fe_node)
    add_child(fe_node, "Fe")
  end

  def fes()
    return children_by_edgelabels(["Fe"])
  end
end

##########
class FeNode < GraphNode

  def FeNode._load(string)
    id, features_s, children_s, parents_s =
      string.split("QQSEPVALUESQQ")

    frame_name, fe_name = FeNode.name_from_id(id)
    result = FeNode.new(frame_name, fe_name)
    result.fill_from_pickle(string)
    return result
  end

  def FeNode.id_from_name(frame_name, fe_name)
    return frame_name + "XXFEXX" + fe_name
  end

  def FeNode.name_from_id(fe_id)
    return fe_id.split("XXFEXX")
  end

  def initialize(frame_name, fe_name)
    super(FeNode.id_from_name(frame_name, fe_name))
    set_f("name", fe_name)
  end

  def add_frame(frame_node)

    unless parents().assoc("Frame").nil? or parents().assoc("Frame").last == frame_node
      # I already have a frame, and it's not this one
      report_problem("Frame", "already set")
    end
      
    add_parent(frame_node, "Frame")
  end

  def frame()
    frames = parents_by_edgelabels(["Frame"])
    if frames.empty?
      return nil
    else
      return frames.first
    end
  end
end

#####

class FramesAndRelations

  def initialize(file)
    
    @frames = Hash.new
    @fes = Hash.new

    $stderr.puts "Reading frames and frame elements."
    doc = Document.new(file)

    # read frames and frame elements from the frames.xml file
    # and enter them in the @frames and @fes hash

    doc.root.elements.each("frame") { |frame_el|
      frame_name = read_oblig_attribute(frame_el, "name")
      new_frame(frame_name)

      frame_el.elements.each("fes/fe") { |fe_el|
	fe_name = read_oblig_attribute(fe_el, "name")
	core_type = read_oblig_attribute(fe_el, "coreType")
	new_fe(frame_name, fe_name)
	get_fe_node(frame_name, fe_name).set_f("coreType", core_type)
      }
    }
  end

  def add_relations(file)

    $stderr.puts "Reading frame and FE hierarchy"

    doc = Document.new(file)

    doc.root.elements.each("frame-relation-type") { |relation|

      case relation.attributes["name"]

      when "Inheritance", "Subframe", "Using", "See_also", "Inchoative_of", "Causative_of"

	$stderr.puts "Reading frame relation " + relation.attributes["name"]
	
	relation.elements.each("frame-relations/frame-relation") { |frame_rel|
	  
	  # enter relation info as graph edge from superframe to subframe
	  superframe = read_oblig_attribute(frame_rel, "superFrameName")
	  subframe = read_oblig_attribute(frame_rel, "subFrameName")
	  
	  add_frame_relation(relation.attributes["name"], superframe, subframe)
	  
	  # enter same relation for frame elements
	  frame_rel.elements.each("fe-relation") { |fe_rel|
	    
	    superfe = read_oblig_attribute(fe_rel,"superFEName")
	    subfe = read_oblig_attribute(fe_rel, "subFEName")
	    
	    ensure_fe_of_frame(superframe, superfe)
	    ensure_fe_of_frame(subframe, subfe)
	    
	    add_fe_relation(relation.attributes["name"], superframe, superfe, subframe, subfe)
	  }
	}

      when "Excludes", "Requires"
	$stderr.puts "Reading frame element relation " + relation.attributes["name"]
	
	relation.elements.each("frame-relations/frame-relation") { |frame_rel|
	  # just one frame mentioned in frame_rel
	  frame_name = read_oblig_attribute(frame_rel, "superFrameName")
	  # this is really about the frame elements
	  frame_rel.elements.each("fe-relation") { |fe_rel|
	    
	    superfe = read_oblig_attribute(fe_rel,"superFEName")
	    subfe = read_oblig_attribute(fe_rel, "subFEName")
	    
	    ensure_fe_of_frame(frame_name, superfe)
	    ensure_fe_of_frame(frame_name, subfe)
	    
	    add_fe_relation(relation.attributes["name"], frame_name, superfe, frame_name, subfe)
	  }
	}

      when "ReFraming_Mapping", "CoreSet"
	#ignore them

      else
	$stderr.print "Warning: Unknown frame/FE relation ", relation.attributes["name"], "\n"
      end
    }
  end

  def recover_from_dump()

    # construct method for recovering
    # a node by its ID
    proc_get_node = proc { |node_id|
      if @frames.has_key? node_id
	@frames[node_id]
      elsif @fes.has_key? node_id
	@fes[node_id]
      else
	$stderr.puts "Error: In trying to recover from dump,"
	$stderr.puts "encountered unknown node ID "+node_id.to_s
	exit 1
      end
    }

    # after pickling and restoring, all graph edges
    # of GraphNode objects point to node IDs rather
    # than to nodes. Restore the nodes from their IDs.
    [@frames, @fes].each { |hash|
      hash.each_value { |node|
	node.recover_from_dump(proc_get_node)
      }
    }
    
  end

  def frames()
    return @frames.values()
  end

  def fes()
    return @fes.values()
  end

  def get_frame(frame_name)
    return @frames[frame_name]
  end

  def get_fe(frame_name, fe_name)
    return @fes[FeNode.id_from_name(frame_name, fe_name)]
  end

  def add_frame_relation(relation, frame_name_1, frame_name_2)
    upper = get_frame_node(frame_name_1)
    lower = get_frame_node(frame_name_2)
    
    upper.add_child(lower, relation)
    lower.add_parent(upper, relation)
  end

  def add_fe_relation(relation, frame_name_1, fe_name_1, frame_name_2, fe_name_2)
    upper = get_fe_node(frame_name_1, fe_name_1)
    lower = get_fe_node(frame_name_2, fe_name_2)
    
    upper.add_child(lower, relation)
    lower.add_parent(upper, relation)
  end

  private

  ###
  def read_oblig_attribute(elem, attr)
    retv = elem.attributes[attr]
    if retv.nil?
      report_problem(elem, "Couldn't read attribute "+attr)
    end
    return retv
  end

  ###
  def record_frame_fe_rel(frame_node, fe_node)
    fe_node.add_frame(frame_node)
    frame_node.add_fe(fe_node)
  end    

  ###
  def ensure_fe_of_frame(frame_name, fe_name)
    fe = get_fe_node(frame_name, fe_name)
    frame = get_frame_node(frame_name)
    unless fe.frame() == frame
      record_frame_fe_rel(frame, fe)
    end
  end

  ###
  def new_frame(frame_name)
    @frames[frame_name] = FrameNode.new(frame_name)
  end

  ### 
  def new_fe(frame_name, fe_name)
    new_fe_id = FeNode.id_from_name(frame_name, fe_name)
    @fes[new_fe_id] = FeNode.new(frame_name, fe_name)

    record_frame_fe_rel(get_frame_node(frame_name), @fes[new_fe_id])
  end

  def get_frame_node(id)
    if @frames[id].nil?
      new_frame(id)
    end
    
    return @frames[id]
  end

  ###
  def get_fe_node(frame_name, fe_name)
    if @fes[FeNode.id_from_name(frame_name, fe_name)].nil?
      new_fe(frame_name, fe_name)
    end

    return @fes[FeNode.id_from_name(frame_name, fe_name)]
  end

  ###
  def report_problem(rexml_element, message)
    $stderr.puts "FramesAndRelations Error: "+message
    unless rexml_element.nil?
      rexml_element.write($stderr)
    end
    exit 1
  end
end

