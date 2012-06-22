# SalsaTigerRegXML.rb
#
# Katrin Erk, June 2005
#
# Classes for accessing and managing 
# SalsaTigerXML sentences
#
# The interface of the classes in this package
# is similar to that of SalsaTigerXML.rb
# but the package is based solely on regular expressions
# and not on REXML.
#
# Main class here: SalsaTigerSentence, keeps a complete sentence
#
# Nodes of the syntactic tree, frames and frame elements are all
# handed around as XMLNode objects, or more specifically 
# SynNode, FrameNode and FeNode objects, respectively. 
#
# Inheritance between classes in here:
#
#                  GraphNode
#                    |
#                  XMLNode
#                    |
#                SalsaTigerXmlNode
#                /                 \
#              SynNode            SemNode
#               |                 /     \
#            TSSynNode      FrameNode   FeNode
#
# 
# SalsaTigerSentence uses the other classes, but is separate
#
# SalsaTigerSentence does _not_ yield a faithful image of the SalsaTiger XML structure of 
# a sentence. With the SalsaTiger XML structure you need to follow "idref" attributes
# to the elements with matching "id" attributes in other parts of the structure.
# With the classes in this package, you don't. 
# Wherever in SalsaTiger XML you have an idref, you will have _direct access to the 
# object_ here. 
#
# Suppose that in the XML structure you have a nonterminal element X with <edge> elements
# pointing to other (terminal or nonterminal) elements X1,.., Xn. Then you'll have 
# a SynNode object N that contains X as its XML object, and the children N1,..,Nn of N 
# will be SynNode objects that contain X1,..,Xn as their XML objects.
#
# A SynNode that is a terminal may have children too: its splitword parts (if any).
#
# So: a syntactic node is a SynNode object, its children are SynNode objects. The edges
# to its children are labeled the same way as in the XML structure. If the children
# are splitword parts, the edges are unlabeled.
#
# A frame is a FrameNode object, its children are FeNode objects. The edges to its children
# are labeled with the FE name or with "target".
#
# A frame element is an FeNode object, its children are SynNode objects. The edges to its
# children are unlabeled.
#
# A frame underspecification is an UspNode object, its children are FrameNode objects.
# The edges to its children are unlabeled.
#
# A frame element underspecification is an UspNode objects, its children are
# FeNode objects. The edges to its children are unlabeled.

require "frprep/Tree"
require "frprep/STXmlTerminalOrder"
require "frprep/RegXML"
require "frprep/ruby_class_extensions"

#############
# class XMLNode
# 
# node with entries pointing to its children
# as well as its parent. 
# all edges may be labeled.
# each node has a unique ID.
# 
# indexes a string with XML data representing the same node, 
# but does not look into it, just keeps it
# 
# methods:
# This class inherits from TreeNode and GraphNode. 
# See Tree.rb and Graph.rb for the methods they offer.
#
# new        initializes the object
#
# get        returns the XML object representing
#            the same node as this node object
#

class XMLNode < TreeNode

  ###
  def initialize(name,        # string: element name; or, for text, the whole text
                 attribute,   # hash: attr_name(string) -> attr_value(string)
                 id,          # string: node ID
                 i_am_text = false) # boolean: set to anything but false or nil
                              # to represent not an xml element but text

    if id.nil?
      # I wasn't given any ID
      # take system time for an ID
      # use to_f to get fractions of seconds too:
      # If I make several nodes in the same second,
      # they should still have unique IDs
      id = Time.new().to_f.to_s
    end

    super(id)

    # remember values for this element
    set_f("name", name)
    set_f("attributes", attribute)
    set_f("i_am_text", i_am_text)

    # sanity check
    if i_am_text and attributes
      raise "A text element cannot have attributes"
    end

    @kith = Array.new()
  end

  ###
  # add sanity check:
  # if this is text rather than an xml element,
  # it cannot have children
  def add_child(child, edgelabel, varhash={})
    if get_f("i_am_text")
      raise "A text element cannot have children"
    end
    super(child, edgelabel, varhash)
  end

  ###
  def add_kith(xml) # RegXML object
    @kith << xml
  end

  ###
  # set attribute
  def set_attribute(name, value)
    unless value.class == String
      raise "I can only set attribute values to strings. Got: #{value.class.to_s}"
    end

    if get_f("attributes").nil?
      set_f("attributes", Hash.new())
    end
    get_f("attributes")[name] = value
  end

  ###
  def get_attribute(name)
    if get_f("attributes")
      return get_f("attributes")[name]
    else
      return nil
    end
  end

  ###
  # delete attribute
  def del_attribute(name)
    if get_f("attributes")
      get_f("attributes").delete(name)
    end
  end  

  ###
  # return XML as string:
  # If this is a text, just return the text
  # which is stored in "name"
  # If this is an XMl element,
  # make a tag from its name and attributes,
  # then add tags for all its children,
  # then add an end tag.
  def get()
    if get_f("i_am_text")
      # text rather than XML element
      return get_f("name")
    else
      # XMl element, not text
      string = "<" + get_f("name")
      if get_f("attributes")
        string << get_f("attributes").to_a.map { |name, value|
          " " + name + "=\'" + xml_secure_val(value) + "\'"
        }.join()
      end
      string << ">\n"
      string << get_xml_embedded()
      string << "</#{get_f("name")}>\n"
      return string
    end
  end
  
  #############
  protected

  def get_xml_embedded()
    return get_xml_ofchildren() +
           get_xml_ofkith()
  end


  def get_xml_ofchildren()
    return children.map { |child|
      child.get()
    }.join()
  end


  def get_xml_ofkith()
    return @kith.map { |thing| thing.to_s + "\n" }.join()
  end  
    

  ###
  def warn_child_ignored(where, xml_node)
    $stderr.puts "WARNING: additional material found in #{where}, will be ignored:"
    $stderr.puts "\t" + xml_node.to_s
  end
  
  ###
  def xml_secure_val(value) # string: value of an attribute
    return value.gsub(/'/, "&apos;").gsub(/"/, "&apos;&apos;")
    return value
  end
end

#############
# class SalsaTigerXmlNode
#
# additional methods:
#
# is_terminal?    true if this is a Tiger XML terminal node
#
# is_nonterminal? true if this is a Tiger XML nonterminal node
#
# is_splitword?   true if this is a splitword part
#
# is_syntactic?   true for terminal, nonterminal, splitword
#
# is_frame?       true if this is a Salsa/Tiger XML frame
#
# is_target?      true if this is a Salsa/Tiger XML frame target
#
# is_fe?          true if this is a Salsa/Tiger XML frame element
#
# is_outside_sentence? returns false -- this node is not a placeholder for
#                 a node that is outside the current sentence
#                 (but see descendant class TSSynNode)
#
# yield_nodes     returns the list of descendants thatare leaves of the tree
#                 NOTE: this overwrites the Graph.yield_nodes method
#                 since we have to treat splitwords in a special way
#                 empty array if no yield nodes are present
#
# yield_nodes_ordered returns those descendants ordered by precedence 
#                 in the sentence, i.e. their node IDs.
# 
# sid             returns the sentence ID of this node
#
# to_s            returns the yield of this node as a string of space-separated words
#                 words ordered left to right
# 
class SalsaTigerXmlNode < XMLNode
  include StringTerminalsInRightOrder

  ###
  # extracting the ID from a RegXML element
  # depends on whether it has an ID or an IDref
  #
  # returns: a string, the ID, or nil if none was found
  def SalsaTigerXmlNode.xmlel_id(xml_obj) # RegXML object
    case xml_obj.name
    when "edge", "fenode", "uspitem", "splitword", "other_edge"
      # contains ID ref
      return xml_obj.attributes()["idref"]
    when "part"
      #  contains ID
      return xml_obj.attributes()["id"]
    else
      # something else
      # default: ID is in attribute "id"
      return xml_obj.attributes()["id"]
    end
  end

  ###
  def initialize(xml) # RegXML object or text
    if xml.text?
      # text
      super(xml, nil, nil, true)
    else
      # xml element
      super(xml.name(), xml.attributes(), SalsaTigerXmlNode.xmlel_id(xml), false)
    end
  end

  ###
  def is_terminal?
    return get_f("name") == "t"
  end
  
  ###
  def is_nonterminal?
    return get_f("name") == "nt"
  end

  ###
  def is_splitword?
    return get_f("name") == "part"
  end

  ###
  def is_syntactic?
    if is_terminal? or is_nonterminal? or is_splitword?
      return true
    else
      return false
    end
  end

  ###
  def is_frame?
    return get_f("name") == "frame"
  end

  ###
  def is_target?
    return get_f("name") == "target"
  end
  
  ###
  def is_fe?
    return get_f("name") == "fe"
  end

  ###
  def sid()
    # my node ID starts out with the sentence ID
    id =~ /^(.*?)_/
    return $1
  end

  ###
  def is_outside_sentence?
    return false
  end

  ###
  def yield_nodes()
    # special consideration: splitwords do not count as children!
    if children.reject {|c| c.is_splitword? }.empty?
      return [ self ]
    end

    arr = Array.new
    children.reject { |c| c.is_splitword? }.each { |c| 
      if c.children.reject {|gc| gc.is_splitword? }.empty?
	arr << c
      else
	arr.concat c.yield_nodes()
      end
    }
    return arr
  end

  ###
  def yield_nodes_ordered() # legacy name
    # sort_terminals_and_splitwords_... cannot deal with nonterminals
    # so remove and attach to the end of the chain
    t, nt  = yield_nodes().distribute { |x| x.is_terminal? or x.is_splitword? }
    return sort_terminals_and_splitwords_left_to_right(t).concat(nt)
  end

  ###
  def terminals_sorted() # name parallel to the method of SalsaTigerSentence
    return yield_nodes_ordered()
  end

  ###
  def to_s
    return string_for_node(self)
  end
end

#############
# class SynNode
#
# inherits from SalsaTigerXmlNode,
# adds to it methods specific to nodes
# that describe the syntactic structure
#
# additional/changed methods:
#
# part_of_speech  part_of_speech information as a string,
#         nil for anything but terminal nodes
#
# word    word information for this node as a string,
#         nil for anything but terminal nodes
#
# category category information for this node as a string,
#         nil for anything but nonterminal nodes
#
# is_punct?       true if this is a terminal node and it is a punctuation sign 
#
# get_sem  add a non-tree edge from this syntactic node to a semantic node
#         Idea: this is basically the inverse of the edge pointing from
#         the FeNode to this SynNode, so you can fetch a node's semantics directly
#
# add_sem add non-tree edge from this syntactic node to a FeNode

class SynNode <  SalsaTigerXmlNode

  ###
  def initialize(xml)
    super(xml)

    @sem = Array.new
    @other_links = Array.new
  end

  ###
  def add_link(other_node,        # SynNode
               link_label,        # string: edge label
               attributes = {})   # hash string>string: further attribute-value pairs for the edge

    @other_links << [link_label, other_node, attributes]
  end

  ###
  def get_linked(label = nil)  # string/nil: if string, use only linked with this link_label
    if label
      return @other_links.select { |label_node_attr| label_node_attr.first == label }
    else
      return @other_links
    end
  end

  ###
  def part_of_speech
    if get_attribute("pos")
      return get_attribute("pos").strip
    else
      return nil
    end
  end

  ###
  def category
    if get_attribute("cat")
      return get_attribute("cat").strip
    else
      return nil
    end
  end

  ###
  def word()
    if get_attribute("word")
      return get_attribute("word").strip
    else
      return nil
    end
  end

  ###
  def is_punct?()
    if is_nonterminal?
      # only terminals can be punctuation signs
      return false 
    end

    # next check part of speech
    # this works at least for TIGER corpus annotation
    case part_of_speech 
    when '$.', '$,', '$('
      return true
    end
    if part_of_speech =~ /^PUNC/
      return true
    end

    # known punctuation signs: filtered out for determining maximal constituents

    # no luck with part of speech:
    # check word
    case word
    when ".", ";", ",", ":", "?", "!", "(", ")", "[", "]", "{", "}", "-", "''", "``", "\"", "'"
      return true
    end

    # not a punctuation sign by any of the tests we have applied
    return false
  end

  ###
  def to_s()
    if is_terminal?
      return word
    else
      return super()
    end
  end

  ###
  def get_sem()
    return @sem.clone()
  end

  ###
  def add_sem(fe_node)
    unless fe_node.class == FeNode
      raise "Unexpected class of semantic node: was expecting an FeNode"
    end

    @sem << fe_node
  end

  #############
  protected

  def get_xml_ofchildren()
    string = ""

    each_child_with_edgelabel { |label, child|
      unless child.is_splitword?
        # terminal or nonterminal child.
        # splitwords are handled separately in the "sem" part of the sentence
        if label
          string << "<edge label=\'#{xml_secure_val(label)}\' idref=\'#{xml_secure_val(child.id)}\'/>\n"
        else
          string << "<edge label=\'-\' idref=\'#{xml_secure_val(child.id)}\'/>\n"
        end
      end
    }
    @other_links.each { |label, node, attributes|
      if label
        string << "<other_edge label=\'#{xml_secure_val(label)}\'"
      else
        string << "<other_edge label=\'-\'"
      end
      string <<  " idref=\'#{xml_secure_val(node.id)}\'" 
      if attributes
        string << " " + attributes.to_a.map { |attr, val| "#{xml_secure_val(attr)}=\'#{xml_secure_val(val)}\'" }.join(" ")
      end
      string << "/>\n"
    }
    
    return string
  end
end

#############
# class TSSynNode
#
# inherits from SynNode
#
# describes a syntactic node that isn't really there:
# a reference to a node in another sentence
#
# contains that node's ID, but an empty RegXML object,
# its string is "<unknown>", and you cannot add
# a child to it
#
# new or changed methods:
#-----------------------
#
# is_outside_sentence? returns true
# 
# word                 returns "<unknown>"
#
# add_child raises an error

class TSSynNode < SynNode

  ###
  def initialize(id_string)
    super(RegXML.new("<OTHER_SENTENCE id='" + id_string + "'/>"))
  end

  ###
  def is_outside_sentence?
    return true
  end

  ###
  # word of this node: <unknown>
  def word
    return "<unknown>"
  end

  def add_child(arg1, arg2)
    raise "Not implemented for this class"
  end
end

#############
# class SemNode
#
# common superclass for FrameNode and FeNode,
# with methods that are the same for both:
#
# 
# is_usp?   returns true if the frame/FE is involved in underspecification,
#           else false
#
# flags     returns an array of all the frame/FE flags for this node.
#           members of the array are strings describing the flags
#           that have been set to true
#
# add_flag  add or remove a frame/FE flag
# remove_flag

class SemNode < SalsaTigerXmlNode
  attr_reader :flags

  def initialize(xml) # RegXML object or text
    super(xml)
    # flags: array of FlagNode objects
    @flags = Array.new()
  end

  ###
  def is_usp?
    return get_attribute("usp") == "yes"
  end

  ###
  def add_flag(name) # string: flag name
    @flags << name
  end

  ### 
  def remove_flag(name) # string: flag name
    @flags.delete(name)
  end

  #############
  protected

  def get_xml_embedded()
    return super() + get_xml_offlags()
  end

  def get_xml_offlags()
    # and add flags
    return @flags.map { |flagname|
      "<flag name=\'#{xml_secure_val(flagname)}\'/>\n"
    }.join
  end    
end



#############
# class FrameNode
#
# inherits from SemNode
# adds to it methods specific to nodes
# that describe a frame
#
# additional/changed methods:
#
# name      returns the name of the frame
# set_name  changes the name of the frame to a new name
# target    returns the target (as a FeNode object)
#
# each_child() iterates through FEs, children() returns all FEs
#
# each_fe_by_name A frame node may have several FE children with the same
#           frame element label. While each_child returns them separately,
#           each_fe_by_name lumps FE children with the same frame element label
#           into one FeNode. 
#           Warnings:
#           - the REXML object of the FeNode is that of the first FE child
#             with that frame element label.
#           - Underspecification is ignored! If you have the same FE twice, 
#             and there is underspecification regarding the extent of the FE,
#             the two FE children will be lumped together anyway. 
#             If you don't want that, use each_child instead. 
# 
#
# add_fe CAUTION: please do not call this method directly externally, 
#           use SalsaTigerSentence.add_fe, otherwise the node and its ID
#           will not be recorded in the node list and the node cannot be retrieved
#           via its ID

class FrameNode <  SemNode

  ###
  def target()
    target = children_by_edgelabels(["target"])
    if target.empty?
      $stderr.puts "SalsaTigerRegXML warning: Frame #{id()}: No target, but I got: \n" + child_labels().join(", ")
      return nil
    else
      unless target.length == 1
	raise "target: more than one target to frame "+id()
      end
      return target.first
    end
  end

  ###
  def name
    return get_attribute("name")
  end

  ###
  def set_name(new_name)
    set_attribute("name", new_name)
  end

  ###
  # each_fe: synonym for each_child
  def each_fe()
    each_child { |c| yield c }
  end

  ###
  # fes: synonym for children
  def fes()
    children()
  end

  ###
  def each_fe_by_name()
    child_labels.uniq.each { |fe_name|
      unless fe_name == "target"

	fes = children_by_edgelabels([fe_name])

	if fes.length == 1 
	  # one frame element with that name
	  yield fes.first

	else
	  # several frame elements with that name
	  # combine them

	  combined_fe = FeNode.new(fe_name, id() + "_" + fe_name)
	  fes.each { |fe|
	    fe.each_child() { |child|
	      combined_fe.add_child(child)
	    }
	  }
	  yield combined_fe
	end
      end
    }
  end

  ###
  def add_child(fe_node)
    if fe_node.name == "target" and not(children_by_edgelabels(["target"]).empty?)
      $stderr.puts "Adding second target to frame #{id()}"
      $stderr.puts "I already have: " + children_by_edgelabels(["target"]).map { |t| t.id() }.join(",")
      raise "More than one target."
    end
       
    super(fe_node, fe_node.name)
  end
  
  ###
  def remove_child(fe_node)
    super(fe_node, fe_node.name)
  end

  ###
  def add_fe(fe_name,   # string: name of FE to add
             syn_nodes, # array:SynNode, syntactic nodes that this FE should point to
             fe_id = nil) # string: ID for the new FE

    if fe_name == "target" and not(children_by_edgelabels(["target"]).empty?)
      $stderr.puts "Adding second target to frame #{id()}"
      $stderr.puts "I already have: " + children_by_edgelabels(["target"]).map { |t| t.id() }.join(",")
      raise "More than one target."
    end
       
    # make FE node and list as this frame's child
    unless fe_id
      # no FE ID given, make one myself
      fe_id = id() + "_fe" + Time.new().to_f.to_s
    end

    n = FeNode.new(fe_name, fe_id)
    add_child(n)

    # add syn nodes
    syn_nodes.each { |syn_node|
      n.add_child(syn_node)
    }

    return n
  end
end

#############
# class FeNode
#
# inherits from SemNode,
# adds to it methods specific to nodes
# that describe a frame element or target
#
# additional/changed methods:
#----------------------------
#
# name      returns the name of the frame element, or "target"
#
# add_child, remove_child

class FeNode <  SemNode

  ###
  def initialize(name_or_xml, # either RegXMl object or the name of the FE as a string 
                 id_if_name = nil) # string: ID to use if we just got the name of the FE

    case name_or_xml.class.to_s
    when "String"
      if name_or_xml == "target"
        super(RegXML.new("<target id=\'#{xml_secure_val(id_if_name.to_s)}\'/>"))
        @i_am_target = true
      else
        super(RegXML.new("<fe name=\'#{xml_secure_val(name_or_xml)}\' id=\'#{xml_secure_val(id_if_name.to_s)}\'/>"))
        @i_am_target = false
      end

    when "RegXML"
      super(name_or_xml)

      if name_or_xml.name() == "target"
        @i_am_target = true
      else
        @i_am_target = false
      end
    else
      raise "Shouldn't be here: " + name_or_xml.class.to_s
    end

    # child_attr: keep additional attributes of <fenode> elements,
    # if there are any
    # child_attr: hash syn_node_id(string) -> attributes(hash)
    @child_attr = Hash.new()
  end
  
  ###
  def name
    if @i_am_target
      return "target"
    else
      return get_attribute("name")
    end
  end

  ###
  def add_child(syn_node,
                xml_obj = nil)
    if xml_obj
      # we've been given the fenode XML element
      # see if there are any attributes that we will need:
      # get attributes, remove the idref (we get that from the
      # child's ID directly)
      at = xml_obj.attributes
      at.delete("idref")
      unless at.empty?
        @child_attr[syn_node.id] = at
      end
    end

    super(syn_node, nil, "pointer_insteadof_edge" => true)
  end

  ###
  def remove_child(syn_node, varhash={})
    super(syn_node, nil, "pointer_insteadof_edge" => true)
  end

  #############
  protected

  def get_xml_ofchildren()
    return children.map { |child|
      if @child_attr[child.id()]
        "<fenode idref=\'#{xml_secure_val(child.id())}\'" +
        @child_attr[child.id()].to_a.map { |attr, val|
          " #{attr}=\'#{xml_secure_val(val)}\'"
        }.join() +
        "/>\n"

      else        
        "<fenode idref=\'#{xml_secure_val(child.id())}\'/>\n"
      end
    }.join()
  end
end

#############
# class UspNode
#
# inherits from SalsaTigerXmlNode,
# adds to it methods specific to nodes
# that describe a frame underspecification or frame element underspecification
#
# additional/changed methods:
#----------------------------
#
# new             initializes the object
#    rexml_object: underlying XML object for this node
#    frame_or_fe:  string, either "frame" for frame underspecification
#                  or "fe" for frame element underspecification
#
# add_child, remove_child   add, remove underspecification entry

class UspNode <  SalsaTigerXmlNode

  attr_reader :i_am

  ###
  def initialize(xml_obj,      # RegXMl object
                 frame_or_fe)  # string "frame" or "fe"

    super(xml_obj)
    case frame_or_fe
    when "frame"
      @i_am = "frame"
    when "fe"
      @i_am = "fe"
    else
      raise "new: neither frame nor fe??"
    end
  end

  ###
  def add_child(node, varhash={})
    if node
      super(node, nil, "pointer_insteadof_edge" => true)
    else
      raise "Got nil for a node."
    end

    # set usp. attribute on child
    node.set_attribute("usp", "yes")
  end

  ###
  def remove_child(node, varhash={})
    super(node, nil, "pointer_insteadof_edge" => true)

    # removing "usp" attribute on child
    # this will be wrong if the child is involved in more 
    # than one instance of underspecification!

    $stderr.puts "Warning: unsafe removal of attribute 'usp'"
    node.del_attribute("usp")
  end

  #############
  protected

  def get_xml_ofchildren()
    return children.map { |child|
      "<uspitem idref=\'#{xml_secure_val(child.id)}\'/>\n"
    }.join()
  end

end

#############
class SalsaTigerSentenceGraph < XMLNode
  include StringTerminalsInRightOrder

  attr_reader :node

  def initialize(xml_obj,     # RegXML object
                 sentence_id) # string: ID of this sentence

    # global data:
    # node: hash node_id -> XMLNode object
    #       maps node IDs to the nodes with that ID
    @node = Hash.new
    @sentence_id = sentence_id

    if xml_obj
      # we actually have syntactic information.
      # read it.
      
      # initialize this object as an XML node,
      # i.e. remember the outermost element's name, attributes, 
      # and ID, and specify that it's not a text but an XML object
      super(xml_obj.name, xml_obj.attributes, sentence_id + "_graph", false)
      
      # initialize nodes, remember their IDs
      xml_obj.children_and_text.each { |child_or_text|
        
        case child_or_text.name
        when "terminals"
          make_nodes(child_or_text, "t", "s/graph/terminals", "all_children_kith")
        when "nonterminals"
          make_nodes(child_or_text, "nt", "s/graph/nonterminals")
        else
          # additional info that we don't need for now
          # keep for output
          add_kith(child_or_text)
        end
      }
      


      # add edges between nodes
      nonterminals = xml_obj.children_and_text.detect { |child| child.name == "nonterminals" }
      if nonterminals
        nonterminals.children_and_text.each { |nt|

          unless nt.name == "nt"
            # we've already done the warning bit in make_nodes
            next
          end

          syn_add_children(@node[SalsaTigerXmlNode.xmlel_id(nt)], nt)
        }
      end

    else
      # we have no syntactic information
      # record it anyway
      
      super("graph", {}, sentence_id + "_graph", false)
    end
  end


  ###
  def add_splitwords(xml_obj)  #RegXMl object
    unless xml_obj.nil?
      # splitwords is an XML element with name "splitwords" and
      # children named "splitword", each of which describes a split
      # for one of the terminals we already know
      xml_obj.children_and_text.each { |splitword|
        unless splitword.name() == "splitword"
          warn_child_ignored("s/sem/splitwords/", splitword)
          next
        end

        # make nodes for the splitword parts
        make_nodes(splitword, "part", "s/sem/splitwords/splitword", "all_children_kith")
        
        # this is the terminal that is being split:
        # add links to its new children
        syn_add_children(@node[SalsaTigerXmlNode.xmlel_id(splitword)], splitword)
      }
    end
  end

  ###
  def to_s
    string_for_nodes(syn_roots())
  end

  ###
  def get()
    # make sure that the graph element has a 'root' attribute
    # since the Salsa tool needs this
    set_attribute("root", syn_roots().first.id())
    super()
  end

  #####
  # access methods

  ###
  def each_node
    @node.each_value { |n| 
      yield n 
    }
  end

  ###
  def nodes
    return @node.values()
  end

  ###
  def each_terminal
    @node.each_value { |node|
      if node.is_terminal?
        yield node
      end
    }
  end

  ###
  def each_terminal_sorted
    sort_terminals_and_splitwords_left_to_right(terminals).each { |node_obj| 
      yield node_obj
    }
  end

  ###
  def terminals
    return @node.values.select { |node| node.is_terminal? }
  end

  ###
  def terminals_sorted
    return  sort_terminals_and_splitwords_left_to_right(terminals)
  end

  ###
  def each_nonterminal
    @node.each_value { |node|
      if node.is_nonterminal?
        yield node
      end
    }
  end

  ###
  def nonterminals
    return @node.values.select { |node| node.is_nonterminal? }
  end

  ###
  def syn_roots
    return @node.values.select { |node|
      node.parent().nil?
    }
  end
  ###

  ######################3
  # adding nodes

  ###
  def add_child(arg1, arg2, varhash={})
    raise "Not implemented for this class"
  end

  ###
  def remove_child(arg1, arg2, varhash={})
    raise "Not implemented for this class"
  end

  ###
  def add_node(sentid,    # string: sentence ID
               label,     # string: t or nt
               cat = nil, # string: category
               word = nil,# string: word
               pos = nil, # string: part of speech
               syn_id = nil)   # string: ID for the new node

    unless ["t", "nt"].include? label
      raise "Unknown node label #{label} for new syntactic node. Must be either t or nt."
    end

    # make node ID: sentence ID plus ID generated by system time
    if syn_id
      new_id = sentid + "_" + syn_id
    else
      new_id = sentid + "_" + Time.new().to_f.to_s
    end

    elt = "<#{label}"
    [["id", new_id], ["cat", cat], ["word", word], ["pos", pos]].each { |label, content|
      if content
        elt << " #{label}=\"#{xml_secure_val(content)}\""
      end
    }
    elt << "/>"
    n = SynNode.new(RegXML.new(elt))
    @node[n.id] = n

    return n
  end

  ###
  def remove_node(node) # SynNode
    # remove node from list
    @node.delete(node.id)

    # remove it as child and parent of other nodes;
    # add its own children to the parent. 
    # the _edgelabel_ of the new edges will be the edgeslabels 
    # between the original node in its children
    # in other words, the label of the removed node's incoming edge
    # is deleted

#    STDERR.puts "Removing node #{node.id}:"
    
    pair = node.parent_with_edgelabel
    if pair
    # delete incoming edge for deleted node
      label, parent = pair
#      STDERR.puts "  Removing link from PARENT #{parent.id}, edgelabel #{label}"
      parent.remove_child(node, label)
    end
    # delete outgoing edge for deleted node
    node.each_child_with_edgelabel { |label, child|
      child.remove_parent(node, label)
#      STDERR.puts "  Removing link to child #{child.id}"
    }
    # glue deleted node's children to its parent    
    if pair
      plabel, parent = pair      
      node.each_child_with_edgelabel {|clabel,child|
        parent.add_child(child, clabel)
      }
#      STDERR.puts "Parent now has children "+node.parent.children.map {|c| c.id}.join(" ")
    end
  end

  ######################
  protected
    
  ###
  def get_xml_ofchildren()
    string = ""

    string << "<terminals>\n"
    each_terminal_sorted { |t|
      string << t.get()
    }
    string << "</terminals>\n"

    string << "<nonterminals>\n"
    each_nonterminal { |nt|
      string << nt.get()
    }
    string << "</nonterminals>\n"

    return string
    
  end

  def make_nodes(xml_obj,  # RegXML object
                 expected_obj_name, # string
                 where, # string
                 all_children_kith = nil) # object: if non-nil,
                                          # keep all children of the new nodes
                                          # as kith" 
    
    xml_obj.children_and_text.each { |elt|

      if elt.name == expected_obj_name
        # this is the kind of child we were expecting to see
        n = SynNode.new(elt)
        @node[n.id] = n

        if all_children_kith
          elt.children_and_text.each { |elt_child|
            n.add_kith(elt_child)
          }
        end
        
      else
        warn_child_ignored(where, elt)
      end
    }
  end
  
  def syn_add_children(node,
                       xml_obj)
    unless node
      raise "Shouldn't be here"
    end
    
    xml_obj.children_and_text.each { |edge|

      if ["edge", "part"].include? edge.name()

        # add an edge to this child,
        # retrieve the node with the given ID from id_to_node
        child = @node[SalsaTigerXmlNode.xmlel_id(edge)]
        unless child
          raise "Sentence #{@sentence_id}: I cannot find a node for " + edge.to_s()
        end
        
        edgelabel = edge.attributes()["label"]
        node.add_child(child, edgelabel)

      elsif edge.name() == "other_edge"
        # add link to this node,
        # retrieve the node with the given ID from id_to_node
        child = @node[SalsaTigerXmlNode.xmlel_id(edge)]
        unless child
          raise "Sentence #{@sentence_id}: I cannot find a node for other_edge #{SalsaTigerXmlNode.xmlel_id(edge)} : " + edge.to_s()
        end
        
        attributes = edge.attributes()
        if attributes
          edgelabel = attributes.delete("label")
        else
          edgelabel = nil
        end
        node.add_link(child, edgelabel, attributes)

      else
        # something other than an edge
        # keep for output
        node.add_kith(edge)
      end
    }
  end
end

#############
class SalsaTigerSentenceSem < XMLNode

  attr_reader :node

  ###
  def SalsaTigerSentenceSem.get_splitwords(xml_obj)
    return xml_obj.children_and_text.detect { |child|
      child.name == "splitwords"
    }
  end

  ###
  def initialize(xml_obj,      # RegXML object  
                 sentence_id,  # string: sentence ID
                 id_to_node)   # hash: syn_node_id(string) -> SynNode object

    # global data:
    # node: hash node_id -> XMLNode object
    #       maps node IDs to the nodes with that ID
    # frame_id, uspframe_id, uspfe_id: arrays of node IDs,
    #   listing all frame nodes, frame underspecification nodes,
    #   and FE underspecification nodes respectively
    # globals: array of RegXML objects, each representing one sentence flag
    @node = Hash.new
    @frame_id = Array.new
    @uspframe_id = Array.new
    @uspfe_id = Array.new
    @globals = Array.new

    if xml_obj
      # we actually have semantic information.
      # read it.

      super(xml_obj.name, xml_obj.attributes, sentence_id + "_sem", false)

      globals_obj = frames_obj = usp_obj = nil

      xml_obj.children_and_text.each { |obj|
        case obj.name
        when "globals"
          globals_obj = obj
        when "frames"
          frames_obj = obj
        when "usp"
          usp_obj = obj
        else
          add_kith(obj)
        end
      }
      
      # handle globals
      if globals_obj
        globals_obj.children_and_text.each { |obj|
          @globals << obj
        }
      end

      # index frames
      if frames_obj
        frames_obj.children_and_text.each { |frame|
          unless frame.name() == "frame"
            warn_child_ignored("s/sem/frames/", frame)
            next
          end
          
          # make a node for the frame.
          node = FrameNode.new(frame)
          semnode_add_flags(node, frame)
          @node[node.id] = node
          @frame_id << node.id
          # add FEs
          frame_add_children(node, frame, id_to_node)
        }
      end

      # index underspecification
      if usp_obj
        usp_obj.children_and_text.each { |uspframe_or_fe|
          case uspframe_or_fe.name
          when "uspframes"
            initialize_usp(uspframe_or_fe, "frame")            
          when "uspfes"
            initialize_usp(uspframe_or_fe, "fe")            

          else
            warn_child_ignored("s/sem/usp/", uspframe_or_fe)
          end
        }
      end

    else
      # we have no semantic information
      # record it anyway

      super("sem", {}, sentence_id + "_sem", false)
    end
  end
  
  ################################################3
  # access methods

  ###
  def each_frame 
    @frame_id.each { |node_id|
      yield @node[node_id]
    }
  end

  ###
  def frames
    return @frame_id.map { |node_id| @node[node_id] }
  end

  ###
  def each_usp_frameblock
    @uspframe_id.each { |node_id|
      yield @node[node_id]
    }
  end

  ###
  def usp_frameblocks()
    return @uspframe_id.map { |node_id| @node[node_id] }
  end

  ###
  def each_usp_feblock
    @uspfe_id.each { |node_id|
      yield @node[node_id]
    }
  end

  ###
  def usp_feblocks()
    return @uspfe_id.map { |node_id| @node[node_id] }
  end

  ###
  def flags
    return @globals.map { |xml_obj|
      { "type" => xml_obj.attributes["type"],
       "param" => xml_obj.attributes["param"],
       "text" => xml_obj.children_and_text.map { |c| c.to_s }.join
      }
    }
  end

  ################################################3
  # adding and removing things

  ###
  def add_frame(sentid,  # string: sentence ID
                name,    # string: name of the frame
                sem_id = nil) # string: ID for the new node

    # make a node for the frame
    if sem_id
      frameid = sem_id
    else
      frameid = sentid + "_f" + Time.new().to_f.to_s
    end
    n = FrameNode.new(RegXML.new("<frame id=\"#{frameid}\" name=\"#{name}\"/>"))
    @node[n.id] = n
    @frame_id << n.id

    return n
  end

  ###
  def remove_frame(frame_node)
    @node.delete(frame_node.id)
    @frame_id.delete(frame_node.id)
  end

  ###
  def add_fe(frame_node, # FrameNode
             fe_name,    # string: name of new FE
             fe_children, # array:SynNode, children of new FE
             sem_id = nil) # optional: ID of new FE


    new_fe = frame_node.add_fe(fe_name, fe_children, sem_id)
    @node[new_fe.id] = new_fe
    return new_fe
  end

  ###
  def remove_fe(fe_node)
    @node.delete(fe_node.id)
    fe_node.parent.remove_child(fe_node)
  end

  ###
  def add_usp(frame_or_fe)    # string: "frame" or "fe"

    n = UspNode.new(RegXML.new("<uspblock/>"), frame_or_fe)
    @node[n.id] = n
    case frame_or_fe
    when "frame"
      @uspframe_id << n.id
    when "fe"
      @uspfe_id << n.id
    else
      raise "Shouldn't be here"
    end

    return n
  end

  ###
  def remove_usp(usp_node)
    usp_node.children.each { |child|
      usp_node.remove_child(child)
    }
    @node.delete(usp_node.id)
    case usp_node.i_am
    when "frame"
      @uspframe_id.delete(usp_node.id)
    when "fe"
      @uspfe_id.delete(usp_node.id)
    else
      raise "Shouldn't be here"
    end
  end


  ###
  def add_child(arg1, arg2)
    raise "Not implemented for this class"
  end

  ###
  def remove_child(arg1, arg2)
    raise "Not implemented for this class"
  end

  ###
  def add_flag(type, param=nil, text=nil)
#    unless ["REEXAMINE", "WRONGSUBCORPUS", "INTERESTING", "LATER"].include? type
#      raise "add_flag: unknown type "+type
#    end

    newglob = "<global type=\'#{xml_secure_val(type)}\'"
    if param
      newglob << " param=\'#{xml_secure_val(param)}\'"
    end
    if text
      newglob << "> #{text} </global>"
    else
      newglob << "/>"
    end

    newglob = RegXML.new(newglob)
    @globals << newglob
    return newglob
  end

  ###
  def remove_flag(type, param=nil, text=nil)
    
    remove_ix = nil
    @globals.each_with_index { |glob,ix|
      if glob.attributes("type") == type
        if param.nil? or glob.attributes("param") == param
          if text.nil? or glob.children_and_text.map { |c| c.to_s }.join == text
            # found it
            remove_ix = ix
            break
          end
        end
      end
    }

    if remove_ix
     return  @globals.delete_at(remove_ix)
    else
      return nil
    end
  end

  ############################3
  protected

  def get_xml_ofchildren()
    string = ""

    # globals
    string << "<globals>\n"
    @globals.each { |glob|
      string << glob.to_s + "\n"
    }
    string << "</globals>\n"

    # frames
    string << "<frames>\n"
    each_frame { |frame_node|
      string << frame_node.get()
    }
    string << "</frames>\n"

    # underspecification
    string << "<usp>\n"
    string << "<uspframes>\n"
    each_usp_frameblock { |block|
      string << block.get()
    }
    string << "</uspframes>\n"
    string << "<uspfes>\n"
    each_usp_feblock { |block|
      string << block.get()
    }
    string << "</uspfes>\n"    
    string << "</usp>\n"

    return string
  end

  ###
  def semnode_add_flags(sem_node,  # SemNode object
                        xml_obj)   # RegXML object

    xml_obj.children_and_text.each { |child|
      if child.name == "flag"
        # found a flag, record it
        name = child.attributes["name"]
        if name
          sem_node.add_flag(name)
        else
          $stderr.puts "Warning: flag without a name"
        end
      end
    }
  end

  def frame_add_children(frame_node, # FrameNode object
                         xml_obj,    # RegXML object
                         id_to_node) # hash: syn_node_id(string) -> SynNode object

    xml_obj.children_and_text.each { |fe|
      case fe.name
      when "fe", "target"
#        $stderr.puts "Da: #{fe.name}\n#{fe.to_s}"

        # make a node for this,
        # and add it as child of this frame node.
        fe_node = FeNode.new(fe)
        @node[fe_node.id] = fe_node
        frame_node.add_child(fe_node)

        semnode_add_flags(fe_node, fe)

        # add the FE's children
        fe.children_and_text.each { |fechild|
          case fechild.name
          when "fenode"

            syn_node = id_to_node[SalsaTigerXmlNode.xmlel_id(fechild)]
            if syn_node
              # normal syntactic node, which the id_to_node mapping knows
              fe_node.add_child(syn_node, fechild)
              syn_node.add_sem(fe_node)

            else
              # must be a node in a different sentence
              # make a dummy graph node for it
              fe_node.add_child(TSSynNode.new(SalsaTigerXmlNode.xmlel_id(fechild)), fechild)
            end

          when "flag"
            # nothing to do, we've handled that already
          else
            fe_node.add_kith(fechild)
          end
        }

      when "flag"
        # nothing to do, wee handled that already

      else
        # keep for output
        frame_node.add_kith(fe)
      end
    }
  end

  ###
  def initialize_usp(xml_obj,      # RegXML object
                     frame_or_fe)  # string: "frame" or "fe"

    xml_obj.children_and_text.each { |uspblock|
      unless uspblock.name == "uspblock"
        warn_child_ignored("s/sem/usp/uspframe|uspfe", uspblock)
        next
      end

      # node for this underspecified block
      n = UspNode.new(uspblock, frame_or_fe)
      @node[n.id] = n

      case frame_or_fe
      when "frame"
        @uspframe_id << n.id
      when  "fe"
        @uspfe_id << n.id
      else
        raise "Shouldn't be here"
      end

      # add its children
      uspblock.children_and_text.each { |uspitem|
        unless uspitem.name == "uspitem"
          warn_child_ignored("s/sem/usp/uspframe|uspfe/uspblock", uspitem)
          next
        end

        usp_id = SalsaTigerXmlNode.xmlel_id(uspitem)
	usp_id = usp_id.gsub(/.*_s/, "s") 
	
        unless @node[usp_id]
          $stderr.puts "Error: Underspecification: could not find node with ID #{usp_id}. Skipping."
          next
        end
        n.add_child(@node[usp_id])
      }
    }
  end
end


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
#	    key "text": a string, the text of this flag. Will be
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

#######
# identify the set of maximal constituents covering a set of nodes
#
module MaxConst

  # returns: array:SynNode, list of maximal constituents covering
  # the input nodes
  def max_constituents_for_nodes(node_list, # array: SynNode
                                 ignore_empty_terminals = false) # boolean: ignore empty terminals?

    # sort node IDs into splitwords and rest,
    # and filter out punctuation marks
    #
    # 'words' is an array of node IDs that are not splitwords
    # 'splitwords' is an array of fenodes that refer to splitwords
    words = Array.new
    splitwords = Array.new
    
    node_list.each { |node|
      if node.is_splitword?
        splitwords << node
      else
        words.concat node.yield_nodes().reject { |t| t.is_punct? }
      end
    }

    # check all nodes from root down:
    # 'constituents', 'nodes_to_check' are arrays of node IDs
    # 'constituents' contains found constituents,
    # 'nodes_to_check' contains nodes for which we still need constituents
    
    constituents = Array.new
    nodes_to_check = syn_roots() # (there may be more than one) 
    # this accesses the syn_roots() method of SalsaTigerSentence
    
    while(true)
      node = nodes_to_check.shift()
      # have we checked all nodes already? or are we done with all words? then stop.
      if node.nil?
	constituents.concat words
	words = []
	break
      end
      if words.empty?
	break
      end
      
      # only match nonempty non-punctuation nodes

      node_yield = node.yield_nodes.reject {|n| n.is_punct? }
      if ignore_empty_terminals
        node_yield = node_yield.reject { |n| n.is_terminal? and (n.word.nil? or n.word.empty?) }
      end
      if node_yield.empty?
        # this node has no yield, or only punctuation sign yield.
        # skip it.
        next
      end
      
      rest = node_yield - words
      if rest.size == 0
        # whole yield of node consists of words from this FE
	constituents << node
	words = words - node_yield
	
      elsif rest.size < node_yield.size
	# at least some of the words in FE appear below this node:
	# check this node's children too
	node.children.each{ |child| nodes_to_check << child }
      end
    end
    
    constituents.concat(splitwords) #splitwords stay what they are
    constituents.concat(words) # any leftover words that may not be from that sentence?
    # just keep them.    

    return constituents
  end

  ###
  # determine maximum constituents covering the nodes in node_list
  # punctuation terminals (and optionally empty terminals) are ignored.
  #
  # If include_single_missing_children is set to true,
  # then a node that has at least one child whose yield is in nodelist,
  #   and has only one child whose yield is not in nodelist,
  #   will be considered as having its yield in nodelist.
  #
  # Optionally, a procedure accept_anyway_proc can be given.
  # Like the option include_single_missing_children, it can lead to nodes being
  # included in the list of nodes whose yield nodes are all also yield nodes of node_list (NYNAAYNN)
  # even though not all of their yield nodes are yield nodes of the node_list.
  # accept_anyway_proc can implement arbitrary rules for including nodes in NYAAYNN.
  # The procedure is called with three arguments:
  #   accept_anyway_proc(node, ch_in, ch_out)
  # node is a SynNode that would not normally be in NYAAYNN.
  # ch_in is the list of its children that are in NYAAYNN.
  # ch_out is the list of its children that are not.
  # If the procedure exists and returns true, node is put into NYAAYNN.
  #
  # returns: an array of SynNodes: the maximal constituents that together
  #    exactly cover node_list
  def max_constituents_smc(node_list, # array: SynNode
                           include_single_missing_children, # boolean
                           ignore_empty_terminals = false, # boolean: ignore empty terminals?
                           accept_anyway_proc = nil) # proc: SynNode, array:SynNode, array:SynNode => boolean

    # sort node IDs into splitwords and rest,
    # and filter out punctuation marks
    #
    # 'words' is an array of node IDs that are not splitwords
    # 'splitwords' is an array of fenodes that refer to splitwords
    words = Array.new
    splitwords = Array.new
    
    node_list.each { |node|
      if node.is_splitword?
        splitwords << node
      else
        words.concat node.yield_nodes().reject { |t| t.is_punct? }
      end
    }

    constituents = splitwords

    syn_roots().each { |node|
      node_included, descendants_included = max_constituents_aux(node, words, 
                                                                 include_single_missing_children, 
                                                                 ignore_empty_terminals,
                                                                 accept_anyway_proc)

      if node_included == "true"
        constituents << node
      else
        constituents.concat descendants_included
      end
    }
    # which words remain to be added?
    constituents.each { |c| words = words - c.yield_nodes() }
    constituents.concat words

    return constituents
  end
  
  ##########33
  private
  
  ###
  # recursively determine maximum constituents covering the nodes in 'nodelist',
  # starting at 'node'.
  # punctuation terminals (and optionally empty terminals) are ignored.
  #
  # If include_single_missing_children is set to true,
  # then a node that has at least one child whose yield is in nodelist,
  #   and has only one child whose yield is not in nodelist,
  #   will be considered as having its yield in nodelist.
  #
  # If accept_anyway_proc is nonnil, also use that to decide whether
  # a node will be considered as having its yield in nodelist.
  #
  # returns: pair [mybool, included_descendants]
  #  where mybool is a string, "true", "false" or "ignoreme" (for ignored 
  #          punctuation and empty terminals):
  #          does the yield of this node consist entirely of nodes from nodelist?
  #  and included_descendants is a list of SynNodes: if mybool is "false", 
  #          this is a list of descendants of this node whose yield does consist
  #          entirely of nodes from nodelist
  def max_constituents_aux(node,    # SynNode
                           nodelist, # array:SynNode
                           include_single_missing_children = false, # boolean
                           ignore_empty_terminals = false, # boolean: ignore empty terminals?
                           accept_anyway_proc = nil) # proc: SynNode, array:SynNode, array:SynNode => Boolean


    
    if node.is_terminal? and nodelist.include? node
      # node is terminal and included in nodelist
      return ["true", []]
    elsif node.is_punct?
      # punctuation: ignore
      return ["ignoreme", []]
    elsif ignore_empty_terminals and node.is_terminal? and
        (node.word.nil? or node.word.empty?)
      # empty terminal: possibly ignore
      return ["ignoreme", []]
    elsif node.is_terminal?
      # terminal, but not included in nodelist
      return ["false", []]
    end
    
    children_results = node.children.map { |ch|
      fully_included, descendants_included = max_constituents_aux(ch, nodelist, 
                                                                  include_single_missing_children, 
                                                                  ignore_empty_terminals,
                                                                  accept_anyway_proc)
      [ch, fully_included, descendants_included]
    }
    
    res_false = children_results.select { |ch, fully_included, descendants_included| 
      fully_included == "false" 
    }
    res_true  = children_results.select { |ch, fully_included, descendants_included| 
      fully_included == "true"
    }

    if res_false.empty? and res_true.length() > 0
      # all true, or all true and ignoreme
      return ["true", []]

    elsif res_false.empty? and res_true.empty? 
      # all ignoreme
      return ["ignoreme", []]

    elsif res_false.length() == 1 and res_true.length() > 1 and
        include_single_missing_children
      # one child not covered,
      # resulting in all other children (except the ignoremes) being marked individually:
      # consider the single missing child as covered, too
      
      return ["true", []]

    elsif accept_anyway_proc and 
        accept_anyway_proc.call(node, res_true.map { |ch, bool1, bool2| ch }, res_false.map { |ch, bool1, bool2| ch })
      # some external source tells us that
      # we are to consider the missing children as covered, too
      return ["true", []]

    else
      # not all children covered
      return [
        "false",
        children_results.map { |ch, fully_included, descendants_included|
          if fully_included == "true"
            [ch]
          else
            descendants_included
          end
        }.flatten
      ]
    end
  end
end

module ConvexComp
  
  def convex_complemented(node_set)

    terminals = terminals_sorted()

    yield_nodes = node_set.map {|node| node.yield_nodes_ordered}.flatten
    leftmost =  yield_nodes.map {|t| terminals.index(t)}.min
    rightmost = yield_nodes.map {|t| terminals.index(t)}.max
    if leftmost.nil? or rightmost.nil?
      STDERR.puts "Warning: could not complement projected node set #{yield_nodes.map {|t| t.id}}; terminals not found in sorted set of sentence terminals!?"
      return node_set
    else
      STDERR.puts "Replacing "+yield_nodes.join(" ")
      new_node_set = terminals[leftmost..rightmost]
      STDERR.puts "By        "+new_node_set.join(" ")
      return max_constituents_for_nodes(new_node_set)
    end
  end
end

class SalsaTigerSentence
  include MaxConst
  include ConvexComp
end
