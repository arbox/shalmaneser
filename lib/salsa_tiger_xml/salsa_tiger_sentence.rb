require_relative 'xml_node'
require_relative 'salsa_tiger_sentence_graph'
require_relative 'salsa_tiger_sentence_sem'
require_relative 'reg_xml'

module STXML
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
    def self.empty_sentence(sentence_id)  # string
      sentence_id = sentence_id.gsub(/'/, "&apos;")
      sent_string = "<s id=\'#{sentence_id}\'>\n" +
                    "<graph/>\n" +
                    "<sem/>\n" +
                    "</s>"

      SalsaTigerSentence.new(sent_string)
    end

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
      xml_syn_obj = xml_obj.children_and_text.detect { |thing|
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
      xml_sem_obj = xml_obj.children_and_text.detect { |thing|
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
      xml_obj.children_and_text.each do |child_or_text|
        case child_or_text.name
        when "graph", "sem"
        # we have handled them already
        else
          add_kith(child_or_text)
        end
      end
    end

    def to_s
      @syn.to_s
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
      @syn.terminals
    end

    ###
    def terminals_sorted
      @syn.terminals_sorted
    end

    ###
    def each_nonterminal
      @syn.each_nonterminal { |n| yield n }
    end

    ###
    def nonterminals
      @syn.nonterminals
    end

    ###
    def each_syn_node
      @syn.each_node { |n| yield n }
    end

    ###
    def syn_nodes
      @syn.nodes
    end

    ###
    def syn_roots
      @syn.syn_roots
    end

    ###
    def syn_node_with_id(syn_id)
      @syn.node[syn_id]
    end

    ###
    def sem_node_with_id(sem_id)
      @sem.node[sem_id]
    end

    ###
    def each_frame
      @sem.each_frame { |f| yield f }
    end

    ###
    def frames
      @sem.frames
    end

    ###
    def each_usp_frameblock
      @sem.each_usp_frameblock { |b| yield b }
    end

    ###
    def usp_frameblocks
      @sem.usp_frameblocks
    end

    ###
    def each_usp_feblock
      @sem.each_usp_feblock { |b| yield b }
    end

    ###
    def usp_feblocks
      @sem.usp_feblocks
    end

    ###
    def flags
      @sem.flags
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

      @syn.add_node(id, label, cat, word, pos, syn_id)
    end

    ###
    def remove_syn(node)
      @syn.remove_node(node)
    end

    ###
    def add_frame(name,    # string: name of the frame
                  sem_id = nil) # string: ID for the new node

      @sem.add_frame(id, name, sem_id)
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

      @sem.add_fe(frame_obj, name, fe_children, sem_id)
    end

    ###
    def remove_fe(fe_node)
      @sem.remove_fe(fe_node)
    end

    ###
    def add_usp(frame_or_fe)
      @sem.add_usp(frame_or_fe)
    end

    ###
    def remove_usp(usp_node) # UspNode object
      @sem.remove_usp(usp_node)
    end

    ###
    def add_flag(type, param = nil, text = nil)
      @sem.add_flag(type, param, text)
    end

    ###
    def remove_flag(type, param = nil, text = nil)
      @sem.remove_flag(type, param, text)
    end

    ###
    def remove_semantics
      empty_sem = RegXML.new("<sem/>")
      @sem = SalsaTigerSentenceSem.new(empty_sem, id, @syn.node)
    end

    #################
    # output
    def get_syn
      @syn.get
    end

    def convex_complemented(node_set)
      terminals = terminals_sorted

      yield_nodes = node_set.map { |node| node.yield_nodes_ordered }.flatten

      leftmost =  yield_nodes.map { |t| terminals.index(t) }.min
      rightmost = yield_nodes.map { |t| terminals.index(t) }.max
      if leftmost.nil? || rightmost.nil?
        STDERR.puts "Warning: could not complement projected node set "\
                    "#{yield_nodes.map(&:id)}"\
                    "Terminals not found in sorted set of sentence terminals!?"
        return node_set
      else
        STDERR.puts "Replacing " + yield_nodes.join(" ")
        new_node_set = terminals[leftmost..rightmost]
        STDERR.puts "By        " + new_node_set.join(" ")
        return max_constituents_for_nodes(new_node_set)
      end
    end

    # returns: array:SynNode, list of maximal constituents covering
    # the input nodes
    def max_constituents_for_nodes(node_list, # array: SynNode
                                   ignore_empty_terminals = false) # boolean: ignore empty terminals?

      # sort node IDs into splitwords and rest,
      # and filter out punctuation marks
      #
      # 'words' is an array of node IDs that are not splitwords
      # 'splitwords' is an array of fenodes that refer to splitwords
      words = []
      splitwords = []

      node_list.each { |node|
        if node.is_splitword?
          splitwords << node
        else
          words.concat node.yield_nodes.reject { |t| t.is_punct? }
        end
      }

      # check all nodes from root down:
      # 'constituents', 'nodes_to_check' are arrays of node IDs
      # 'constituents' contains found constituents,
      # 'nodes_to_check' contains nodes for which we still need constituents

      constituents = []
      nodes_to_check = syn_roots # (there may be more than one)
      # this accesses the syn_roots() method of SalsaTigerSentence

      while(true)
        node = nodes_to_check.shift
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
          words -= node_yield

        elsif rest.size < node_yield.size
          # at least some of the words in FE appear below this node:
          # check this node's children too
          node.children.each { |child| nodes_to_check << child }
        end
      end

      constituents.concat(splitwords) #splitwords stay what they are
      constituents.concat(words) # any leftover words that may not be from that sentence?
      # just keep them.

      constituents
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
      words = []
      splitwords = []

      node_list.each { |node|
        if node.is_splitword?
          splitwords << node
        else
          words.concat node.yield_nodes.reject { |t| t.is_punct? }
        end
      }

      constituents = splitwords

      syn_roots.each { |node|
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
      constituents.each { |c| words -= c.yield_nodes }
      constituents.concat words

      constituents
    end

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

      if res_false.empty? and res_true.length > 0
        # all true, or all true and ignoreme
        return ["true", []]

      elsif res_false.empty? and res_true.empty?
        # all ignoreme
        return ["ignoreme", []]

      elsif res_false.length == 1 and res_true.length > 1 and
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

    protected

    def get_xml_ofchildren
      @syn.get + @sem.get
    end
  end
end
