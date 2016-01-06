require_relative 'xml_node'
require_relative 'string_terminals_in_right_order'

module STXML
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
  def self.xmlel_id(xml_obj) # RegXML object
    case xml_obj.name
    when "edge", "fenode", "uspitem", "splitword", "other_edge"
      # contains ID ref
      xml_obj.attributes["idref"]
    when "part"
      #  contains ID
      xml_obj.attributes["id"]
    else
      # something else
      # default: ID is in attribute "id"
      xml_obj.attributes["id"]
    end
  end

  ###
  # RegXML object or text
  def initialize(xml)
    if xml.text?
      # text
      super(xml, nil, nil, true)
    else
      # xml element
      super(xml.name, xml.attributes, SalsaTigerXmlNode.xmlel_id(xml), false)
    end
  end

  ###
  def is_terminal?
    get_f("name") == "t"
  end

  ###
  def is_nonterminal?
    get_f("name") == "nt"
  end

  ###
  def is_splitword?
    get_f("name") == "part"
  end

  ###
  def is_syntactic?
    is_terminal? || is_nonterminal? || is_splitword?
  end

  ###
  def is_frame?
    get_f("name") == "frame"
  end

  ###
  def is_target?
    get_f("name") == "target"
  end

  ###
  def is_fe?
    get_f("name") == "fe"
  end

  ###
  def sid
    # my node ID starts out with the sentence ID
    id =~ /^(.*?)_/
    return $1
  end

  ###
  def is_outside_sentence?
    false
  end

  ###
  def yield_nodes
    # special consideration: splitwords do not count as children!
    if children.reject { |c| c.is_splitword? }.empty?
      return [self]
    end

    arr = []
    children.reject { |c| c.is_splitword? }.each { |c|
      if c.children.reject(&:is_splitword?).empty?
        arr << c
      else
        arr.concat c.yield_nodes
      end
    }

    arr
  end

  ###
  def yield_nodes_ordered # legacy name
    # sort_terminals_and_splitwords_... cannot deal with nonterminals
    # so remove and attach to the end of the chain
    t, nt  = yield_nodes.distribute { |x| x.is_terminal? || x.is_splitword? }
    return sort_terminals_and_splitwords_left_to_right(t).concat(nt)
  end

  ###
  # name parallel to the method of SalsaTigerSentence
  def terminals_sorted
    return yield_nodes_ordered
  end

  ###
  def to_s
    string_for_node(self)
  end
end
end
