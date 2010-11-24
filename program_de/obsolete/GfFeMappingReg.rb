# GfFeMapping
# Katrin Erk April 05
# adapted to SalsaTigerRegXML June 05
#
# given a SalsaTigerSentence object
# that has a frame with a verb target,
# map all FEs of this frame to 
# grammatical functions of the verb
# and return the mappings as hashes

require "TigerVerbsReg"
require "SalsaTigerRegXML"
require "SalsaLemmaFromFilename"
require "headz"

class GfFeMapping
  include SalsaLemmaFromFilename

  ##
  # new()
  def initialize()
    @h_obj = Headz.new()
  end

  ###
  # fes_and_gfs_for_frame
  #
  # given a frame, determine all FE/GF mappings,
  # as well as FEs not mapped to GFs and
  # GFs not mapped to FEs
  #
  # GFs can only be detemined for verb targets,
  # for other targets all FEs will be non-mapped
  # 
  # returns a list of hashes, each of them representing one mapping,
  # with keys
  #
  # - fe: FE name, may be nil for GF not mapped to any FE.
  #       The same FE name occurs in several mappings if 
  #       there were several syntactic nodes assigned for this FE
  #
  #       FE name is "target" for the target.
  #
  # - gf: GF name, may be nil if this syntactic node assigned for this FE
  #       does not correspond to any GF of the target
  #
  # - nodes: list of SynNode objects, all syntactic nodes assigned for 
  #       this FE. may be empty list
  #
  # - headnode: SynNode object, the head node for this GF or FE.
  #       This is determined using the Headz class, except in the case
  #       when several syntactic nodes have been assigned for a target,
  #       in which case there's a separate heuristic
  #       May be nil if head couldn't be determined
  #
  # - headword: string, terminal word of the headnode
  #       May be nil if head couldn't be determined
  #
  # - headindex: string, index of the headnode, counting the terminals of the sentence
  #       in order of occurrence
  #       May be nil if head couldn't be determined
  #
  # - prep: string, preposition of the GF, may be nil
  #
  #
  # - prepindex: string, index of preposition node, counting the terminals of the sentence
  #       in order of occurrence; may be nil
  #
  # - voice: string, "active" or "passive" for verb targets, nil else

  def fes_and_gfs_for_frame(frame_obj, # FrameNode object from SalsaTigerXML
		 sent_obj,  # SalsaTigerSentence object from SalsaTigerXML
		 filename)  # string: name of the file in which the sentence occurred, may be nil
                            # Salsa file name schema is used to determine target lemma if it is missingframe_obj, 

    # gf_fe_mapping_for_frame:
    # returns a pair [properties, mapping]
    # where properties is an array containing the voice of the target,
    # and mapping is an array of triples
    # [fe_name(string, may be nil if only the GF is known,
    #  gf_name(string, may be nil if only the FE is known,
    #  main_node(SynNode, main of following list of nodes),
    #  nodes(array of SynNodes filling the FE/GF)]

    properties, mappings = gf_fe_mapping_for_frame(frame_obj, sent_obj,
                                                   filename)
    voice = properties.first

    return mappings.map { |fe_name, gf_name, node, allnodes_fe|

      # head word and position
      head = get_terminal_head(node)

      if head
	headindex = terminal_position(head)
	headword = head.to_s
      else
	headword = headindex = nil
      end

      # does this role/gf have a preposition?
      prep_node_and_name = get_prep(node)

      if prep_node_and_name
	prep_name = prep_node_and_name.last
	prep_index = terminal_position(prep_node_and_name.first)
      else
	prep_name = prep_index = nil
      end

      { "fe" => fe_name,
       "gf" => gf_name,
       "nodes" => allnodes_fe,
       "headnode" => head,
       "headword" => headword,
       "headindex" => headindex,
       "prep" => prep_name,
       "prepindex" => prep_index,
       "voice" => voice
      }
    }

  end

  ###
  # words_and_indices
  #
  # given a mapping hash (as returned by fes_and_gfs_for_frame),
  # take the 'nodes' entry of the hash
  # and map it to a list of terminal words plus
  # a list of terminal indices,
  # make each into a space-separated string
  #
  # returns: two strings, first for head words, second for head indices
  def words_and_indices(mapping) # hash for gf/fe mapping as returned by fes_and_gfs_for_frame
    if mapping.nil?
      return []
    end

    nodelist = terminals_of_nodelist(mapping["nodes"])
    
    words = nodelist.map { |n| n.to_s}.join(" ")

    indices = nodelist.map { |n| terminal_position(n)}.compact.map { |i| i.to_s }.join(" ")

    return [words, indices]
  end    

  ###
  private

  ##
  # gf_fe_mapping_for_frame:
  #
  # given a sentence and a frame, map all FEs of this frame
  # to grammatical functions.
  #
  # works only for verb targets.
  #
  # returns: a pair [frame_props(array:string), mappings(array)]
  #   frame_props contains general properties of the frame
  #     at the moment, there is just one feature: voice: "active" or "passive" for verb targets,
  #     nil for others.
  #   mappings: an array of tuples 
  #     [fe(string/nil), gf(string/nil), main_node(SynNode), nodes(array of SynNode)] where
  #     nodes are the syntactic nodes filling the FE/the GF, and 
  #     main_node is the main one among those nodes, determined according to the 
  #     heuristic in main_node_of_nodelist()
  #
  def gf_fe_mapping_for_frame(frame_obj, # FrameNode object from SalsaTigerXML
			      sent_obj,  # SalsaTigerSentence object from SalsaTigerXML
			      filename)  # string: name of the file in which the sentence occurred, may be nil
                                         # Salsa file name schema is used to determine target lemma if it is missing
    mapping = Array.new

    ## 
    # first deal with the target
    main_target = find_main_target(frame_obj, sent_obj, filename)


    # store info on target:
    # - fe = "target"
    # - gf = nil
    # - main target is main_target
    # - all nodes: all children of frame_obj.target()
    mapping << ["target", nil, main_target, frame_obj.target.children()]
      
    grfuncs = []
    voice = nil
    if main_target 
      # construct a list of tuples [relation, node]
      # where 'relation' is some grammatical function, a string
      case main_target.part_of_speech()
      when /^V[VAM]/
	grfuncs = TigerVerbsModule.get_all_rels_of_verb(main_target)

        # verb: also determine voice
        obj = TigerVerbsModule::Misc.new()
        if obj.is_passive(main_target)
          voice = "passive"
        else
          voice = "active"
        end

      when "NN", "NE"
	grfuncs = TigerNounsAdjectivesModule.get_all_rels_of_n(main_target, sent_obj)
      when "ADJA"
	grfuncs = TigerNounsAdjectivesModule.get_all_rels_of_a(main_target)
      end
    end

    # try to match with frame elements:
    # if an FE points to more than one syntactic node,
    # try to match each of them separately
    frame_obj.each_fe_by_name() { |fe_node|

      if fe_node.name.nil?
	next
      end

      unless fe_node.name() == "target"
	fe_name = fe_node.name.gsub(" ", "_")
	
	fe_node.each_child { |n|
	  # iterate through constituents that are fe_node's children

	  # is this node listed in the list of grammatical functions?
	  grfunc = grfuncs.detect { |rel, othernode|
	    othernode == n
	  }

	  if grfunc
	    rel, othernode = grfunc
	    # matching grammatical function found
	    mapping << [fe_name, rel, othernode, fe_node.children]
	  else
	    # no matching grammatical function found for this member of the FE
	    # construct a dummy tuple:
	    # - FE name, 
	    # - no grammatical function name
	    # - node: the first child of the FE node
	    mapping << [fe_name, nil, n, fe_node.children]
	  end
	}
      end
    }

    # add those GFs that didn't match anything
    grfuncs.each { |rel, node|
      # try to find this GF in the list of [fe, gf, nodes] triples
      if mapping.detect {|fe_name, otherrel, othernode, othernodes|
	  rel == otherrel and node == othernode
	}.nil?
	# GF that wasn't matched by any triple
	mapping << [nil, rel, node, [node]]
      end
    }
    
    properties = [voice]
    
    return [properties, mapping]
  end

  ###
  # terminals_of_nodelist
  #
  # given a list of SalsaTigerNode objects, map them to a list of
  # SynNode objects representing the leaves below the original nodelist:
  # terminal or splitword nodes
  def terminals_of_nodelist(nodelist) # array of SalsatigerNode objects
    if nodelist.nil? or nodelist.length == 0
      return []
    end

    return  nodelist.map { |n| n.yield_nodes() }.flatten.uniq.find_all { |t|
      t.is_terminal? or t.is_splitword?
    }
  end

  ####
  # find_main_target
  #
  # determine the main terminal for the target of a given frame
  #
  # if there is only one syntactic node for the target, its head
  # as determined by the Headz object is the main target.
  #
  # if there are several syntactic nodes for the target,
  # turn them into a list of terminals, then use the following heuristic:
  #   if we have a verb with separate verb prefix, the verb is the main node
  #   otherwise, if there is a verb, the first verb is the main node
  #   otherwise, if there is a noun, the first noun is the main node
  #   otherwise, if there is an adjective, the first adjective is the main node
  #   otherwise the first terminal is main 
  #
  # if there is no syntactic node for the target,
  # try to determine the lemma from the filename,
  # then find a terminal matching the lemma
  # 
  # returns: main node(SynNode) or nil
  def find_main_target(frame_obj, sent_obj, filename)

    targets = frame_obj.target.children()

    if targets.length() == 1
      # exactly one syntactic node for the target:
      # return its head terminal
      return get_terminal_head(targets.first)

    elsif targets.length() > 1
      # more than one syntactic node for the target:
      # use heuristics to determine main target
      # from a list

      targets = terminals_of_nodelist(targets)

 
      # remove separate verb prefixes from list
      targets = targets.reject { |node|
	node.part_of_speech() == "PTKVZ"
      }
      # exactly one node, except for the separate verb prefix
      if targets.length() == 1
	return targets.first
      end
    
      # find first verb
      targets.each { |node|
	if node.part_of_speech() =~ /^V/
	  return node
	end
      }
    
      # find first noun
      targets.each { |node|
	if node.part_of_speech() =~ /^N/
	  return node
	end
      }
    
      # find first adjective
      targets.each { |node|
	if node.part_of_speech() =~ /^ADJ/
	  return node
	end
      }
    
      # just return first node
      return targets.first()

    else
      # no syntactic node given for target:
      # use filename to determine lemma, 
      # then try to find matching terminal

      lemma = determine_lemma_from_filename(filename)
      if lemma
	lemma = lemma[0..-3] # cut off last 2 characters to remove "en" at end of infinitive
	sent_obj.each_terminal { |node|
	  if node.word().include? lemma
	    return node
	  end
	}
      end


      # couldn't find target this way
      return nil
    end
  end

  #####
  # determine preposition:
  # node is a syn node that may (or may not) describe a PP
  # return nil if no preposition could be found,
  # otherwise a pair [preposition as syn node, preposition as lowercase string]
  #
  # node: SynNode object
  
  def get_prep(node)
    if node.nil?
      return nil
    end
    
    hhash = @h_obj.get_sem_head(node)
    if hhash.nil?
      return nil
    else
      prepnode = hhash["prep"]
      if prepnode.nil?
	return nil
      else
	return [prepnode, prepnode.to_s.downcase()]
      end
    end
  end



  #################
  # get_terminal_head
  #
  # use Aljoscha's headz package
  # to determine the terminal head of the constituent
  # that 'node' (a syn node object) refers to
  #
  # node: SynNode object
  # h_obj:Headz object
  #
  # returns a SynNode object, the head (or nil, if it doesn't work)
  def get_terminal_head(node) # SynNode object

    # go on finding heads until you reach a terminal
    # or until node becomes nil: may be because we've been handed a 'nil' 
    # as a parameter, or because get_sem_head couldn't determine a head
    while not(node.nil?) and not(node.is_terminal?) and not(node.is_splitword?)
      hhash = @h_obj.get_sem_head(node)
      if hhash.nil?
	return nil
      else
	node = hhash["head"]
      end
    end
    
    return node
  end

  ####################
  # terminal_position
  #
  # given a terminal, determine its position in the sentence:
  # normally, its ID is <sentence_id>_<position>
  # so try to extract that position and return it as a string
  #
  # failing that, it may be part of a splitword with ID
  # <sentence_id>_<position>_s<position_within_word>
  # so extract the number in the middle
  #
  # if all that fails, return nil
  #
  # node: SynNode object, a terminal of a Salsa/Tiger XML sentence
  # 
  # returns: a string, the position of the terminal in the sentence.
  #       the string contains a number (starting at 1)
  #       nil if we couldn't determine the number
  def terminal_position(node)
    if node.nil?
      return nil
    end

    if node.id() =~ /^s\d+_(\d+)$/
      return $1
    end
    
    if node.id() =~ /^s\d+_(\d+)_\w+$/
      return $1
    end
    
    return nil
  end
end
