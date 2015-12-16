#############################
# abstract class, to be inherited:
#
# interpretation for a POS tagger/lemmatizer/parser combination
class SynInterpreter

  ###
  # systems interpreted by this class:
  # returns a hash service(string) -> system name (string),
  # e.g.
  # { "parser" => "collins", "lemmatizer" => "treetagger" }
  def SynInterpreter.systems
    raise "Overwrite me"
  end

  ###
  # names of additional systems that may be interpreted by this class
  # returns a hash service(string) -> system name(string)
  # same as names()
  def SynInterpreter.optional_systems
    raise "Overwrite me"
  end

  ###
  # generalize over POS tags.
  #
  # returns one of:
  #
  # adj:  adjective (phrase)
  # adv:  adverb (phrase)
  # card: numbers, quantity phrases
  # con:  conjunction
  # det:  determiner, including possessive/demonstrative pronouns etc.
  # for:  foreign material
  # noun: noun (phrase), including personal pronouns, proper names, expletives
  # part: particles, truncated words (German compound parts)
  # prep: preposition (phrase)
  # pun:  punctuation, brackets, etc.
  # sent: sentence
  # top:  top node of a sentence
  # verb: verb (phrase)
  # nil:  something went wrong
  #
  # default: return phrase type as is
  #
  # returns: string or nil
  def SynInterpreter.category(node) # SynNode
    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    return eval(self.name).pt(node)
  end

  ###
  # is relative pronoun?
  #
  # default: false
  def SynInterpreter.relative_pronoun?(node) # SynNode
    return false
  end

  ###
  # lemma_backoff:
  #
  # if we have lemma information, return that,
  # and failing that, return the word
  #
  # returns: string or nil
  def SynInterpreter.lemma_backoff(node)
    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    lemma = node.get_attribute("lemma")
    if (lemma.nil? or lemma =~ /unknown/) and
        node.is_terminal?
      return node.word
    else
      return lemma
    end
  end

  ###
  # phrase type:
  # constituent label for nonterminals,
  # part of speech for terminals
  #
  # returns: string
  def SynInterpreter.pt(node)
    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    if node.is_terminal?
      return node.part_of_speech
    else
      return node.category
    end
  end

  ###
  # simplified phrase type:
  # like phrase type, but may simplify
  # the constituent label
  # default: just the same as pt()
  #
  # returns: string or nil
  def SynInterpreter.simplified_pt(node)
    return eval(self.name).pt(node)
  end

  ###
  # particle_of_verb:
  #
  # given a node and a nodelist,
  # if the node represents a verb:
  # see if the verb has a particle among the nodes in nodelist
  # if so, return it
  # default: no recognition of separate particles
  #
  # returns: SynNode object if successful, else nil
  def SynInterpreter.particle_of_verb(node,
                                      node_list)
    return nil
  end

  ###
  # auxiliary?
  #
  # returns true if the given node is an auxiliary
  # default: no recognition of auxiliaries
  #
  # returns: boolean
  def SynInterpreter.auxiliary?(node)
    return false
  end

  ###
  # modal?
  #
  # returns true if the given node is a modal verb
  # default: no recognition of modals
  #
  # returns: boolean
  def SynInterpreter.modal?(node)
    return false
  end

  ###
  # head_terminal
  #
  # given a constituent, return the terminal node
  # that describes its headword
  # default: a heuristic that assumes the existence of a 'head'
  #   attribute on nodes:
  #   find the first node in my yield corresponding to my head attribute..
  #
  # returns: a SynNode object if successful, else nil
  def SynInterpreter.head_terminal(node)
    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    if node.is_terminal?
      return node
    end

    head = node.get_attribute("head")
    unless head
      return nil
    end

    return node.yield_nodes.detect { |t|
      t.get_attribute("word") == head
    }
  end

  ###
  # voice
  #
  # given a constituent, return
  # - "active"/"passive" if it is a verb
  # - nil, else
  #
  # default: treat all as active
  def SynInterpreter.voice(node)
    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    if eval(self.name).category(node) == "verb"
      return "active"
    else
      return nil
    end
  end

  ###
  # gfs
  #
  # grammatical functions of a constituent:
  #
  # returns: a list of pairs [relation(string), node(SynNode)]
  # where <node> stands in the relation <relation> to the parameter
  # that the method was called with
  #
  # default: children of this node, with edge labels as relations,
  # prepositions tacked on for pps
  def SynInterpreter.gfs(node,    # SynNode
                         sent)    # SalsaTigerSentence
    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    return node.children_with_edgelabel.map { |rel, gf_node|

      if eval(self.name).category(gf_node) == "prep"
        [rel + "-" + eval(self.name).preposition(gf_node).to_s, gf_node]
      else
        [rel, gf_node]
      end
    }
  end

  ###
  # informative_content_node
  #
  # for most constituents: the head
  # for a PP, the NP
  # for an SBAR, the VP
  # for a VP, the embedded VP
  #
  # Default: returns the first non-head child
  def SynInterpreter.informative_content_node(node)
    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    headlemma = eval(self.name).lemma_backoff(node)

    first_nonhead_child = node.children.detect { |n|
      nnh = eval(self.name).head_terminal(n)
      nnh and
        eval(self.name).lemma_backoff(nnh) != headlemma
    }

    return first_nonhead_child
  end

  #####################################
  # verbs(sent)  sent is a sentence in SalsaTigerSentence format
  #
  # return a list of the nodes of full verbs in a given sentence:
  # it is a list of lists. An item in that list is
  # - either a pair [verb, svp]
  #   of the node of a verb with separable prefix
  #   and the node of its separate prefix
  # - or a singleton [verb]
  #   of the node of a verb without separate prefix
  def SynInterpreter.verbs(sent)

    return sent.syn_nodes.select { |node|
      eval(self.name).category(node) == "verb"
    }.map { |node|
      [node]
    }
  end

  ###
  # governing verbs
  #
  # returns a list of pairs [rel, verb_node]
  # such that the given node fills the grammatical function rel
  # for this verb_node
  # or an empty list if there is no such verb
  def SynInterpreter.governing_verbs(node,
                                     sent)
    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    retv = []

    # each verb of the sentence:
    eval(self.name).verbs(sent).each { |verb_node, prefix_node|
      # each gf of this verb:
      eval(self.name).gfs(verb_node, sent).each { |rel, other_node|
        # if it points to the given node, record
        if other_node == node or
            eval(self.name).informative_content_node(other_node) == node
          retv << [rel, verb_node]
          break
        end
      }
    }

    return retv
  end

  ###
  # path_between
  #
  # construct path in syntactic structure between two nodes,
  # using
  # - node labels
  # - edge labels
  # - direction Up, Down
  #
  # use_nontree_edges: set to true to use coreference edges
  # and other non-tree edges returned by the parser
  # in path computation. (Will produce no change if the parser
  # does not produce any non-tree edges.)
  #
  # returns: Path object
  def SynInterpreter.path_between(from_node, # SynNode
                                  to_node,   # SynNode
                                  use_nontree_edges = false) # boolean

    unless from_node.kind_of? SynNode and to_node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    path = eval(self.name).search_up(from_node,to_node, nil)

    if path.nil?
      # no path found
#      STDERR.puts "Warning: no path found between #{to_node.id} and #{from_node.id}"
    end

    return path
  end

  ###
  # surrounding_nodes:
  #
  # construct paths in syntactic structure between a node and each of its neighbors
  # path construction as in path_between.
  # Neighbors: parent, child, plus potentially neighbors by nontree edges
  # use_nontree_edges: again, same as in path_between
  #
  # returns: list of pairs [neighbor(SynNode), path(Path)]
  def SynInterpreter.surrounding_nodes(node, # SynNode
                                       use_nontree_edges = false) # boolean

    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    retv = []

    # parent
    if (p = node.parent)
      retv << [
        p,
        Path.new(node).add_last_step("U", node.parent_label,
                                     eval(self.name).simplified_pt(p), p)
      ]
    end

    # children
    node.each_child_with_edgelabel { |label, c|
      retv << [
        c,
        Path.new(node).add_last_step("D", label,
                                     eval(self.name).simplified_pt(c), c)
      ]
    }

    return retv
  end

  ###
  # relative_position
  # of a node with respect to an (anchor) node:
  # left, right, dom
  def SynInterpreter.relative_position(node,        # SynNode
                                       anchor_node) # SynNode

    unless node.kind_of? SynNode and anchor_node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    # compute up to a root node
    root = node
    while (p = root.parent)
      root = p
    end

    # determine position of {leftmost, rightmost} terminal of
    # {node, anchor_node} in the list of all terminals
    all_yieldnodes = root.yield_nodes_ordered

    pos_nodefirst = all_yieldnodes.index(eval(self.name).leftmost_terminal(node))
    pos_anchorfirst = all_yieldnodes.index(eval(self.name).leftmost_terminal(anchor_node))
    pos_nodelast = all_yieldnodes.index(eval(self.name).rightmost_terminal(node))
    pos_anchorlast = all_yieldnodes.index(eval(self.name).rightmost_terminal(anchor_node))

    # determine relative position
    if pos_nodefirst and pos_anchorfirst and pos_nodefirst < pos_anchorfirst
      return "LEFT"
    elsif pos_nodelast and pos_anchorlast and pos_anchorlast < pos_nodelast
      return "RIGHT"
    else
      return "DOM"
    end
  end

  ###
  # leftmost_terminal
  #
  # given a constituent, determine its leftmost terminal,
  # excluding punctuation
  def SynInterpreter.leftmost_terminal(node)
    leftmost = node.yield_nodes_ordered.detect {|n| eval(self.name).category(n) != "pun"}
    unless leftmost
      leftmost = node.yield_nodes_ordered.first
    end
    return leftmost
  end

  ###
  # rightmost_terminal
  #
  # given a constituent, determine its rightmost terminal,
  # excluding punctuation
  def SynInterpreter.rightmost_terminal(node)
    rightmost = node.yield_nodes_ordered.reverse.detect {|n| eval(self.name).category(n) != "pun"}
    unless rightmost
      rightmost = node.yield_nodes_ordered.last
    end
    return rightmost
  end

  ###
  # preposition
  #
  # if the given node represents a PP, return the preposition
  #
  # default: assume that either the PP node will have the preposition as its lemma,
  # or that the head terminal of the PP will be the preposition
  def SynInterpreter.preposition(node)
    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    # preposition as lemma of this node?
    if eval(self.name).category(node) == "prep" and
        (lemma = eval(self.name).lemma_backoff(node)) and
        not(lemma.empty?)
      return lemma
    end

    # head terminal is preposition and has a lemma?
    hl = eval(self.name).head_terminal(node)
    if hl and
        eval(self.name).category(hl) == "prep" and
        (lemma = eval(self.name).lemma_backoff(hl)) and
        not(lemma.empty?)
      return lemma
    end

    # no luck
    return nil
  end


  ###
  # main node of expression
  #
  # returns: SynNode, main node, if found
  # else nil
  def SynInterpreter.main_node_of_expr(nodelist,
                                       no_mwes = nil) # non-nil: don't handle multiword expressions beyond verbs with separate particles

    # map nodes to terminals
    nodelist1 = nodelist.map { |n| n.yield_nodes }.flatten

    # single node? return it
    if nodelist1.length == 1
      return nodelist1.first
    end

    # more than one word

    # see if we can get a headword of a single constituent
    if nodelist.length == 1 and
        (headword = eval(self.name).head_terminal(nodelist.first))
      return headword
    end

    # filter out auxiliaries and modals, see if only one node remains
    nodelist2 = nodelist1.reject { |t|
      eval(self.name).auxiliary?(t) or
        eval(self.name).modal?(t)
    }

    # one verb, one prep or particle? then
    # assume we have a separate verb prefix, and take the lemma of the verb
    if nodelist2.length == 2
      verbs = nodelist2.select { |t| eval(self.name).category(t) == "verb"}
      if verbs.length == 1
        # found exactly one verb, so we have one verb, one other
        if eval(self.name).particle_of_verb(verbs.first, nodelist2)
          # we have found a particle/separate verb prefix
          # take verb as main node
          return verbs.first
        end
      end
    end

    if no_mwes
      # I was told only to look for separate verb particles,
      # not for anything else, so return nil at this point
      return nil
    end

    # filtered out everything? oops -- return to previous node list
    if nodelist2.empty?
      nodelist2 = nodelist1
    end

    # if the nodelist describes an mwe, try to find its headword:
    # look for the lowest common ancestor of all nodes in nodelist2
    # if its head terminal is in nodelist2, return that
    lca = nodelist2.first
    lca_found = false
    while lca and not(lca_found)
      yn = lca.yield_nodes
      # lca's yield nodes include all nodes in nodelist2?
      # then lca is indeed the lowest common ancestor
      if nodelist2.big_and { |t| yn.include? t }
        lca_found = true
      else
        lca = lca.parent
      end
    end
    # nodelist2 includes lca's head terminal? then return that
    if lca_found and
        (h = eval(self.name).head_terminal(lca)) and
        nodelist2.include? h
      return h
    end


    # try first verb, then first noun, then first adjective
    ["verb", "noun", "adj"].each { |cat|
      nodelist.each { |t|
        if eval(self.name).category(t) == cat
          return t
        end
      }
    }

    # return first node
    return nodelist.first
  end

  ########
  # max constituents:
  # given a set of nodes, compute the maximal constituents
  # that exactly cover them
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
  #
  # default: use the SalsaTigerSentence method for this
  def SynInterpreter.max_constituents(nodeset, # Array:SynNode
                                      sent,    # SalsaTigerSentence
                                      idealize_maxconst = false, # boolean
                                      accept_anyway_proc = nil)  # procedure

    if idealize_maxconst
      return sent.max_constituents_smc(nodeset, idealize_maxconst,
                                       false, # do not ignore empty terminals
                                       accept_anyway_proc)
    else
      return sent.max_constituents_for_nodes(nodeset)
    end
  end

  ########
  # prune?
  # given a target node t and another node n of the syntactic structure,
  # decide whether n is likely to instantiate a semantic role
  # of t. If not, recommend n for pruning.
  #
  # This method is supposed to implement a method similar
  # to the one proposed by Xue and Palmer (EMNLP 2004).
  #
  # returns: true to recommend n for pruning, else false
  #
  # Since the implementation is highly parser-specific,
  # all that we can do in the default method is
  # always to return false.
  def SynInterpreter.prune?(node, # SynNode
                            paths_to_target, # hash: node ID -> Path object: paths from nodes to target
                            terminal_index)  # hash: terminal node -> word index in sentence

    unless node.kind_of? SynNode
      $stderr.puts "Warning: unexpected input class #{node.class} to SynInterpreter"
      return nil
    end

    return false
  end


  ####################3
  protected

  def SynInterpreter.announce_me
    if defined?(SynInterfaces)
      # yup, we have a class to which we can announce ourselves
      SynInterfaces.add_interpreter(eval(self.name))
    else
      # no interface collector class
      $stderr.puts "Interface #{self.name} not announced: no SynInterfaces."
    end
  end

  ####################3
  private

  ###
  # search upward:
  # look for path from from_node to to_node
  # already_covered is either nil or
  # a node whose subtree we have already searched
  def SynInterpreter.search_up(from_node, # SynNode
                               to_node,   # SynNode
                               already_covered) # SynNode
    # returns (1) the path from from_node to to_node,
    #         (2) just the part from the lca down to the node
    #         (3) the lowest common ancestor as node

    path = eval(self.name).search_down(from_node,to_node, already_covered)

    if path.nil?
      # search down unsuccessful

      parent = from_node.parent
      edgelabel = from_node.parent_label
      # puts "Going up from "+from_node.id.to_s+" to "+parent.id.to_s

      if parent.nil?
        # no path found
        return nil

      else
        # search up
        path = eval(self.name).search_up(parent,to_node, from_node)

        if path.nil?
          # no path found
          return nil

        else
          # search up was successful
          parent_pt = eval(self.name).simplified_pt(parent)
          path.add_first_step(from_node, "U", edgelabel, parent_pt)
          return path
        end
      end

    else
      # search down successful
      return path
    end
  end

  ###
  # search in tree
  def SynInterpreter.search_down(from_node,        # SynNode
                                 to_node,          # SynNode
                                 already_explored) # SynNode

    if from_node == to_node
      return Path.new(from_node)

    else

      from_node.children.each {|c|

        if c == already_explored
          # we have done this subtree,
          # don't do it again
          next
        end

        path = eval(self.name).search_down(c, to_node, already_explored)

        unless path.nil?
          c_pt = eval(self.name).simplified_pt(c)
          path.add_first_step(from_node, "D", c.parent_label, c_pt)
          return path
        end
      }

      # no path found for any of the children
      return nil
    end
  end
end
