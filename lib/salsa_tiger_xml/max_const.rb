module STXML
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
    constituents.each { |c| words = words - c.yield_nodes }
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
end
end
