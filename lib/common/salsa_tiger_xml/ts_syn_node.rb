require_relative 'syn_node'

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
