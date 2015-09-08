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

# require "common/Tree"


require "common/RegXML"
require "common/ruby_class_extensions"

require_relative 'salsa_tiger_xml/string_terminals_in_right_order'

require_relative 'salsa_tiger_xml/xml_node'
require_relative 'salsa_tiger_xml/fe_node'
require_relative 'salsa_tiger_xml/frame_node'
require_relative 'salsa_tiger_xml/salsa_tiger_xml_node'
require_relative 'salsa_tiger_xml/syn_node'
require_relative 'salsa_tiger_xml/ts_syn_node'
require_relative 'salsa_tiger_xml/sem_node'
require_relative 'salsa_tiger_xml/usp_node'
require_relative 'salsa_tiger_xml/salsa_tiger_sentence_graph'
require_relative 'salsa_tiger_xml/salsa_tiger_sentence_sem'
require_relative 'salsa_tiger_xml/salsa_tiger_sentence'

require_relative 'salsa_tiger_xml/max_const'
require_relative 'salsa_tiger_xml/convex_comp'

require_relative 'salsa_tiger_xml/graph_node'

require_relative 'salsa_tiger_xml/tree_node'

# require_relative 'salsa_tiger_xml/sem_node'
# require_relative 'salsa_tiger_xml/sem_node'
# require_relative 'salsa_tiger_xml/sem_node'
