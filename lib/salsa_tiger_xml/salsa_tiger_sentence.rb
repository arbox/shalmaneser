require_relative 'xml_node'
require_relative 'convex_comp'
require_relative 'max_const'
require_relative 'salsa_tiger_sentence_graph'
require_relative 'salsa_tiger_sentence_sem'
require_relative 'reg_xml'

#############
# class SalsaTigerSentence
#
# offers access methods to a SalsaTigerXML sentence
# given as a string
#
# Nodes of syntactic structure as well as frames and
# frame elements are kept (and returned) as XMLNode objects,
# or more specifically as SynNode, FrameNode and FeNode objects.
#
# methods:
#
# new      initializes the object
#
# id       returns the sentence ID
#
# get      returns the REXML object describing the same sentence
#          as this object
#
# each_terminal  yields each terminal of the sentence in turn.
#          they are returned as SynNode objects
#
# terminals returns all terminal node objects in an array
#
# each_terminal_sorted  yields each terminal of the sentence in turn,
#          making sure the terminal with the lowest ID is returned first.
#          use this if you need the terminal words in the right order!
#          nodes are returned as SynNode objects
#
# each_nonterminal yields each nonterminal of the sentence in turn.
#           nodes are returned as SynNode objects
#
# each_frame yields each frame of the sentence in turn.
#           nodes are returned as FrameNode objects
#
# frames returns all frame objects in an array
#
# each_usp_frameblock
#          yields each group of underspecified frames of the sentence
#          in turn, as an UspNode object. To see the frames involved
#          in this underspecification, use each_child on the UspNode object
#
#
# usp_frameblocks  returns all groups of underspecified frames as an array
#          of UspNode objects
#
# each_usp_feblock
#          yields each group of underspecified frame elements
#          of the sentence in turn, as an UspNode object.
#          To see the frames involved
#          in this underspecification, use each_child on the UspNode object
#
# usp_feblocks  returns all groups of underspecified frame elements
#          as an array of UspNode objects
#
#
# flags     returns a list of the sentence flags, as hashes.
#           key "type": a string, either REEXAMINE or WRONGSUBCORPUS
#                       or INTERESTING or LATER
#           key "param": a string, the parameter. important for
#                        REEXAMINE
#           key "text": a string, the text of this flag. Will be
#                       nonempty only for INTERESTING cases
#
# syn_roots returns a list of all the roots of the syntactic trees
#           in this sentence, as node objects. There may be more than
#           one, unfortunately.
#
# add_syn  add a new syntactic node with the given category, word, POS,
#          returns the new node
#
# add_frame add a frame with a given name, returns the new frame node
#
# add_usp  add a new underspecification block, either for frames or FEs
#
# add_flag  adds a sentence flag to this sentence.
#   type: a string, must be REEXAMINE, INTERESTING, WRONGSUBCORPUS,
#         or LATER
#   param: optional parameter, a string, describes type of Reexamine
#          for REEXAMINE-type flags
#   text:  optional parameter, a string, arbitrary text commenting
#          on the flag, used mainly with INTERESTING
#
# remove_flag removes a sentence flag to this sentence
#          only removes flag in case of exact match of type, param, and text
#   type: a string, either REEXAMINE, INTERESTING, WRONGSUBCORPUS,
#         or LATER
#   param: optional parameter, a string, describes type of Reexamine
#          for REEXAMINE-type flags
#   text:  optional parameter, a string, arbitrary text commenting
#          on the flag, used mainly with INTERESTING

class SalsaTigerSentence < XMLNode

  def initialize(string)
    # parse string as an XML element
    xml_obj = RegXML.new(string)

    # initialize this object as an XML node,
    # i.e. remember the outermost element's name, attributes,
    # and ID, and specify that it's not a text but an XML object
    super(xml_obj.name, xml_obj.attributes, SalsaTigerXmlNode.xmlel_id(xml_obj), false)

    # find XML element "graph",
    # which contains the syntactic info of the sentence.
    # It is a child of the <s> element.
    xml_syn_obj = xml_obj.children_and_text().detect { |thing|
      thing.name == "graph"
    }

    unless xml_syn_obj
      # no graph in this sentence -- fake one
      xml_syn_obj = RegXML.new("<graph/>")
    end

    @syn = SalsaTigerSentenceGraph.new(xml_syn_obj, id)

    # find XML element "sem"
    # which contains the semantic info of the sentence.
    # It is a child of the <s> element.
    xml_sem_obj = xml_obj.children_and_text().detect { |thing|
      thing.name == "sem"
    }

    unless xml_sem_obj
      # no semantic info in this sentence -- fake one
      xml_sem_obj = RegXML.new("<sem/>")
    end

    # add splitword info to @syn element
    @syn.add_splitwords(SalsaTigerSentenceSem.get_splitwords(xml_sem_obj))

    @sem = SalsaTigerSentenceSem.new(xml_sem_obj, id, @syn.node)

    # go through the children of the <s> object again,
    # remembering all children except <graph> and <sem>
    # for later output
    xml_obj.children_and_text.each { |child_or_text|
      case child_or_text.name
      when "graph", "sem"
        # we have handled them already
      else
        add_kith(child_or_text)
      end
    }

  end

  #############
  def SalsaTigerSentence.empty_sentence(sentence_id)  # string
    sentence_id = sentence_id.gsub(/'/, "&apos;")
    sent_string = "<s id=\'#{sentence_id}\'>\n" +
                  "<graph/>\n" +
                  "<sem/>\n" +
                  "</s>"
    return SalsaTigerSentence.new(sent_string)
  end

  #####


  ###
  def to_s
    return @syn.to_s
  end

  ###
  def each_terminal
    @syn.each_terminal { |n| yield n }
  end

  ###
  def each_terminal_sorted
    @syn.each_terminal_sorted { |n| yield n }
  end

  ###
  def terminals
    return @syn.terminals()
  end

  ###
  def terminals_sorted
    return @syn.terminals_sorted()
  end

  ###
  def each_nonterminal
    @syn.each_nonterminal { |n| yield n }
  end

  ###
  def nonterminals
    return @syn.nonterminals()
  end

  ###
  def each_syn_node
    @syn.each_node {  |n|
      yield n
    }
  end

  ###
  def syn_nodes
    return @syn.nodes()
  end

  ###
  def syn_roots
    return @syn.syn_roots()
  end
  ###

  ###
  def syn_node_with_id(syn_id)
    return @syn.node[syn_id]
  end

  ###
  def sem_node_with_id(sem_id)
    return @sem.node[sem_id]
  end

  ###
  def each_frame
    @sem.each_frame { |f| yield f }
  end

  ###
  def frames
    return @sem.frames
  end

  ###
  def each_usp_frameblock
    @sem.each_usp_frameblock { |b| yield b }
  end

  ###
  def usp_frameblocks()
    return @sem.usp_frameblocks()
  end

  ###
  def each_usp_feblock
    @sem.each_usp_feblock { |b| yield b }
  end

  ###
  def usp_feblocks()
    return @sem.usp_feblocks()
  end

  ###
  def flags
    return @sem.flags()
  end

  ###################################
  # adding and removing things

  ###
  # add syntactic node, specified as terminal(t) or nonterminal(nt)
  #
  # returns the new node
  def add_syn(label,     # string: t or nt
              cat = nil, # string: category
              word = nil,# string: word
              pos = nil, # string: part of speech
              syn_id = nil)  # string: ID for the new node
    return @syn.add_node(id(), label, cat, word, pos, syn_id)
  end

  ###
  def remove_syn(node)
    @syn.remove_node(node)
  end

  ###
  def add_frame(name,    # string: name of the frame
                sem_id = nil) # string: ID for the new node
    return @sem.add_frame(id(), name, sem_id)
  end

  ###
  def remove_frame(frame_node) # FrameNode object
    @sem.remove_frame(frame_node)
  end

  ###
  def add_fe(frame_obj,
             name,
             fe_children,
             sem_id = nil)
    return @sem.add_fe(frame_obj, name, fe_children, sem_id)
  end

  ###
  def remove_fe(fe_node)
    @sem.remove_fe(fe_node)
  end

  ###
  def add_usp(frame_or_fe)
    return @sem.add_usp(frame_or_fe)
  end

  ###
  def remove_usp(usp_node) # UspNode object
    @sem.remove_usp(usp_node)
  end

  ###
  def add_flag(type, param=nil, text=nil)
    @sem.add_flag(type, param, text)
  end

  ###
  def remove_flag(type, param=nil, text=nil)
    @sem.remove_flag(type, param, text)
  end

  ###
  def remove_semantics()
    empty_sem = RegXML.new("<sem/>")
    @sem = SalsaTigerSentenceSem.new(empty_sem, id(), @syn.node)
  end

  #################33
  # output
  def get_syn()
    return @syn.get()
  end

  ############################3
  protected

  def get_xml_ofchildren()
    return @syn.get() + @sem.get()
  end
end


class SalsaTigerSentence
  include MaxConst
  include ConvexComp
end
