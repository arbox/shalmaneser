require_relative 'salsa_tiger_xml_node'

module STXML
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
class SynNode < SalsaTigerXmlNode

  ###
  def initialize(xml)
    super(xml)

    @sem = []
    @other_links = []
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
  def word
    if get_attribute("word")
      return get_attribute("word").strip
    else
      return nil
    end
  end

  ###
  def is_punct?
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
  def to_s
    if is_terminal?
      return word
    else
      return super()
    end
  end

  ###
  def get_sem
    return @sem.clone
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

  def get_xml_ofchildren
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
end
