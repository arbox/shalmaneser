# require 'common/TabFormat'
# require 'common/salsa_tiger_xml/salsa_tiger_sentence'
# require 'common/salsa_tiger_xml/syn_node'
# require 'common/SalsaTigerXMLHelper'

require 'common/AbstractSynInterface'

################################################
# Interpreter class
class CollinsTntInterpreter < SynInterpreter
  CollinsTntInterpreter.announce_me

  ###
  # names of the systems interpreted by this class:
  # returns a hash service(string) -> system name (string),
  # e.g.
  # { "parser" => "collins", "lemmatizer" => "treetagger" }
  def self.systems
    {"pos_tagger" => "treetagger", "parser" => "collins"}
  end

  ###
  # names of additional systems that may be interpreted by this class
  # returns a hash service(string) -> system name(string)
  # same as names()
  def self.optional_systems
    {"lemmatizer" => "treetagger"}
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
  # returns: string, or nil
  def self.category(node) # SynNode
    pt = CollinsTntInterpreter.simplified_pt(node)
    if pt.nil?
      # phrase type could not be determined
      return nil
    end

    pt.to_s.strip =~ /^([^-]*)/
    case $1
    when  /^JJ/, /(WH)?ADJP/, /^PDT/ then  return "adj"
    when /^RB/, /(WH)?ADVP/, /^UH/ then return "adv"
    when /^CD/, /^QP/ then  return "card"
    when /^CC/, /^WRB/, /^CONJP/ then return "con"
    when /^DT/, /^POS/ then  return "det"
    when /^FW/, /^SYM/ then  return "for"
    when /^N/, "WHAD", "WDT", /^PRP/ , /^WHNP/, /^EX/, /^WP/  then return "noun"
    when  /^IN/ , /^TO/, /(WH)?PP/, "RP", /^PR(T|N)/ then return "prep"
    when /^PUNC/, /LRB/, /RRB/, /[,'".:;!?\(\)]/ then  return "pun"
    when /^S(s|bar|BAR|G|Q|BARQ|INV)?$/, /^UCP/, /^FRAG/, /^X/, /^INTJ/ then return "sent"
    when /^TOP/ then  return "top"
    when /^TRACE/ then  return "trace"
    when /^V/ , /^MD/ then return "verb"
    else
      #      $stderr.puts "WARNING: Unknown category/POS "+c.to_s + " (English data)"
      return nil
    end
  end


  ###
  # is relative pronoun?
  #
  def self.relative_pronoun?(node) # SynNode
    pt = CollinsTntInterpreter.simplified_pt(node)
    if pt.nil?
      # phrase type could not be determined
      return nil
    end

    pt.to_s.strip =~ /^([^-]*)/
    case $1
    when /^WDT/, /^WHAD/, /^WHNP/, /^WP/
      return true
    else
      return false
    end
  end

  ###
  # lemma_backoff:
  #
  # if we have lemma information, return that,
  # and failing that, return the word
  #
  # returns: string, or nil
  def CollinsTntInterpreter.lemma_backoff(node)
    lemma = super(node)
    # lemmatizer has returned more than one possible lemma form:
    # just accept the first
    if lemma =~ /^([^|]+)|/
      return $1
    else
      return lemma
    end
  end


  ###
  # simplified phrase type:
  # like phrase type, but may simplify
  # the constituent label
  #
  # returns: string
  def self.simplified_pt(node)
    CollinsTntInterpreter.pt(node) =~ /^(\w+)(-\w)*/
    return $1
  end

  ###
  # verb_with_particle:
  #
  # given a node and a nodelist,
  # if the node represents a verb:
  # see if the verb has a particle among the nodes in nodelist
  # if so, return it
  #
  # returns: SynNode object if successful, else nil
  def self.particle_of_verb(node,
                                             node_list)

    # must be verb
    unless CollinsTntInterpreter.category(node) == "verb"
      return nil
    end

    # must have parent
    unless node.parent
      return nil
    end

    # look for sisters of the verb node that have the particle category
    particles = node.parent.children.select { |sister|
      CollinsTntInterpreter.category(sister) == "part"
    }.map { |n| n.children}.flatten.select { |niece|
      # now look for children of those nodes that are particles and are in the nodelist
      nodelist.include? niece and
        CollinsTntInterpreter.category(niece) == "part"
    }

    if particles.length == 0
      return nil
    else
      return particles.first
    end
  end

  ###
  # auxiliary?
  #
  # returns true if the given node is an auxiliary
  # else false
  def self.auxiliary?(node)

    # look for
    #             ---VP---
    #             |      |
    #  the given node   VP-A
    #                    |
    #                verb node
    # verb?
    unless CollinsTntInterpreter.category(node) == "verb"
      return false
    end

    unless (parent = node.parent) and
          parent.category() == "VP"
      return false
    end
    unless (vpa_node = parent.children.detect { |other_child| other_child.category() == "VP-A" })
      return false
    end
    unless vpa_node.children.detect { |other_node| CollinsTntInterpreter.category(other_node) == "verb" }
      return false
    end

    return true

  end

  ###
  # modal?
  #
  # returns true if the given node is a modal verb,
  # else false
  def self.modal?(node)
    if node.part_of_speech =~ /^MD/
      return true
    else
      return false
    end
  end

  ###
  # voice
  #
  # given a constituent, return
  # - "active"/"passive" if it is a verb
  # - nil, else
  def self.voice(node) # SynNode

    tobe = ["be","am","is","are","was","were"]

    unless CollinsTntInterpreter.category(node) == "verb"
      return nil
    end

    # if we have a gerund, a present tense, or an infitive
    # then we are sure that we have an active form
    case CollinsTntInterpreter.pt(node)
    when "VBG", "VBP", "VBZ", "VB"
      "active"
    end

    # There is an ambiguity for many word forms between VBN (past participle - passive)
    # and VBD (past tense - active)

    # so for these, we only say something if we can exclude one possibility,
    # this is the case
    # (a)  when there is a c-commanding "to be" somewhere. -> passive
    # (b)  when there is no "to be", but a "to have" somewhere. -> active

    # collect lemmas of c-commanding verbs.

    parent = node.parent
    if parent.nil?
      return nil
    end
    gp = parent.parent
    if gp.nil?
      return nil
    end

    #    other_verbs = Array.new
    #
    #    current_node = node
    #    while current_node = current_node.parent
    #      pt =  CollinsTntInterpreter.category(current_node)
    #      unless ["verb","sentence"].include? pt
    #        break
    #      end
    #      current_node.children.each {|child|
    #        if CollinsTntInterpreter.category(child) == "verb"
    #          other_verbs << CollinsTntInterpreter.lemma_backoff(nephew)
    #        end
    #      }
    #    end
    #
    #    unless (tobe & other_verbs).empty?
    #      puts "passive "+node.id
    #      return "passive"
    #    end
    #    unless (tohave & other_verbs).empty?
    #      return "active"
    #    end

    if CollinsTntInterpreter.category(gp) == "verb" or CollinsTntInterpreter.category(gp) == "sent"

      current_node = node

      while current_node = current_node.parent
        pt =  CollinsTntInterpreter.category(current_node)
        unless ["verb","sent"].include? pt
          break
        end
        if current_node.children.detect {|nephew| tobe.include? CollinsTntInterpreter.lemma_backoff(nephew)}
          return "passive"
        end
      end
      # if no "to be" has been found...
      return "active"
    end

    # case 2: The grandfather is something else (e.g. a noun phrase)
    # here, simple past forms are often mis-tagged as passives
    #

    # if we were cautious, we would return "dontknow" here;
    # however, these cases are so rare that it is unlikely that
    # assignments would be more reliable; so we rely on the
    # POS tag anyway.


    case CollinsTntInterpreter.pt(node)
    when "VBN","VBD"
      return "passive"
    # this must be some kind of error...
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
  def CollinsTntInterpreter.gfs(anchor_node,    # SynNode
                                sent)    # SalsaTigerSentence

    return sent.syn_nodes.map { |gf_node|

      case CollinsTntInterpreter.category(anchor_node)
      when "adj"
        rel = CollinsTntInterpreter.gf_adj(anchor_node, gf_node)
      when "verb"
        rel = CollinsTntInterpreter.gf_verb(anchor_node, gf_node)
      when "noun"
        rel = CollinsTntInterpreter.gf_noun(anchor_node, gf_node)
      end

      if rel
        [rel, gf_node]
      else
        nil
      end
    }.compact()
  end

  ###
  # informative_content_node
  #
  # for most constituents: nil
  # for a PP, the NP
  # for an SBAR, the VP
  # for a VP, the embedded VP
  def CollinsTntInterpreter.informative_content_node(node)
    this_pt = CollinsTntInterpreter.simplified_pt(node)

    unless ["SBAR", "VP", "PP"].include? this_pt
      return nil
    end

    nh = CollinsTntInterpreter.head_terminal(node)
    unless nh
      return nil
    end
    headlemma = CollinsTntInterpreter.lemma_backoff(nh)

    nonhead_children = node.children().reject { |n|
      nnh = CollinsTntInterpreter.head_terminal(n)
      not(nnh) or
        CollinsTntInterpreter.lemma_backoff(nnh) == headlemma
    }
    if nonhead_children.length() == 1
      return nonhead_children.first
    end

    # more than one child:
    # for SBAR and VP take child with head POS starting in VB,
    # for PP child with head POS starting in NN
    case this_pt
    when "SBAR", "VP"
      icont_child = nonhead_children.detect { |n|
        h = CollinsTntInterpreter.head_terminal(n)
        h and h.part_of_speech() =~ /^VB/
      }
    when "PP"
      icont_child = nonhead_children.detect { |n|
        h = CollinsTntInterpreter.head_terminal(n)
        h and h.part_of_speech() =~ /^NN/
      }
    else
      raise "Shouldn't be here"
    end

    if icont_child
      return icont_child
    else
      return nonhead_children.first
    end
  end




  ########
  # prune?
  # given a target node t and another node n of the syntactic structure,
  # decide whether n is likely to instantiate a semantic role
  # of t. If not, recommend n for pruning.
  #
  # This method implements a slight variant of Xue and Palmer (EMNLP 2004).
  # Pruning according to Xue & Palmer, EMNLP 2004:
  # "Step 1: Designate the predicate as the current node and
  #    collect its sisters (constituents attached at the same level
  #    as the predicate) unless its sisters are coordinated with the
  #    predicate. If a sister is a PP, also collect its immediate
  #    children.
  #  Step 2: Reset the current node to its parent and repeat Step 1
  #    till it reaches the top level node.
  #
  # Modifications made here:
  # - paths of length 0 accepted in any case
  #
  # returns: false to recommend n for pruning, else true
  def CollinsTntInterpreter.prune?(node, # SynNode
                                   paths_to_target, # hash: node ID -> Path object: paths from target to node
                                   terminal_index)  # hash: terminal node -> word index in sentence

    path_to_target = paths_to_target[node.id()]

    if not path_to_target
      # no path from target to node: suggest for pruning

      return 0

    elsif path_to_target.length == 0
      # target may be its own role: definite accept

      return 1

    else
      # consider path from target to node.
      # (1) If the path to the current node includes at least one Up
      # and exactly one Down,  keep.
      # (2) Else, if the path includes at least one Up and exactly two Down,
      # and the current node's parent is a PP, keep
      # (3) else discard

      # count number of up and down steps in path to target
      num_up = 0
      num_down = 0
      path_to_target.each_step { |direction, edgelabel, nodelabel, endnode|
        case direction
        when /U/
          num_up += 1
        when /D/
          num_down += 1
        end
      }

      # coordination sister between node and target?
      conj_sister_between = CollinsTntInterpreter.conj_sister_between?(node, paths_to_target,
                                                                       terminal_index)


      if conj_sister_between
        # coordination between me and the target -- drop
        return 0

      elsif num_up >= 1 and num_down == 1
        # case (1)
        return  1

      elsif num_up >= 1 and num_down == 2 and
           (p = node.parent()) and CollinsTntInterpreter.category(p) == "prep"

        # case (2)
        return 1

      else
        # case (3)
        return 0
      end
    end
  end


  ###
  private


  ###
  # given an anchor node and another node that may be some
  # grammatical function of the anchor node:
  # return the grammatical function (string) if found,
  # else nil.
  #
  # here: anchor node is verb.
  def CollinsTntInterpreter.gf_verb(anchor_node, # SynNode
                                    gf_node) # SynNode

    # first classification: according to constituent type
    cat = CollinsTntInterpreter.category(gf_node)
    if cat.nil?
      return nil
    end

    # second classification: according to path
    path = CollinsTntInterpreter.path_between(anchor_node, gf_node)
    if path.nil?
      # no path between anchor node and gf node
      return nil
    end

    path.set_cutoff_last_pt_on_printing(true)
    path_string = path.print(true,false,true)

    case path_string
    when "U VP D ", "U SG D "
      categ2 = "inside"
    when /^U (VP U )*S(BAR)? D $/
      categ2 = "external"
    when /^U (VP U )*VP D ADVP D $/
      categ2 = "external"
    else
      categ2 = ""
    end

    # now evaluate based on both
    case cat+ "+" + categ2
    when "noun+inside"
      # direct object
      return  "OA"

    when "noun+external"
      unless CollinsTntInterpreter.relative_position(gf_node, anchor_node) == "LEFT"
        return nil
      end

      if CollinsTntInterpreter.voice(anchor_node) == "passive"
        return "OA"
      else
        return "SB"
      end

    when "prep+inside"
      if CollinsTntInterpreter.voice(anchor_node) == "passive" and
        CollinsTntInterpreter.preposition(gf_node) == "by"
        return "SB"
      else
        return "MO-" + CollinsTntInterpreter.preposition(gf_node).to_s
      end

    when "sent+inside"
      return  "OC"

    when "sent+external"
      return  "OC"

    else
      return nil
    end
  end

  ###
  # given an anchor node and another node that may be some
  # grammatical function of the anchor node:
  # return the grammatical function (string) if found,
  # else nil.
  #
  # here: anchor node is noun.
  def CollinsTntInterpreter.gf_noun(anchor_node,  # SynNode
                                    gf_node)      # SynNode

    # first classification: according to constituent type
    cat = CollinsTntInterpreter.category(gf_node)
    if cat.nil?
      return nil
    end

    # second classification: according to path
    path = CollinsTntInterpreter.path_between(anchor_node, gf_node)
    if path.nil?
      # no path between anchor node and gf node
      return nil
    end

    path.set_cutoff_last_pt_on_printing(true)
    path_string = path.print(true,false,true)

    case path_string
    when "U NPB D "
      categ2 = "np-neighbor"
    when "U NPB U NP D "
      categ2 = "np-parent"
    when "U NP D "
      categ2 = "np-a"
    when /^U NPB (U NP )?(U NP )?U S(BAR)? D( VP D)? $/
      categ2 = "beyond-s"
    when /^U NP(B)? (U NP )?U VP D $/
      categ2 = "beyond-vp"
    when /^U NPB (U NP )?(U NP)?U PP U VP(-A)? D $/
      categ2 = "beyond-pp-vp"
    else
      categ2 = ""
    end

    # now evaluate based on both
    case cat + "+" + categ2
    when "noun+np-neighbor"
      return "AG"

    when "sent+np-parent"
      return "OC"

    when "prep+np-parent", "prep+np-a"
      return "MO-" + CollinsTntInterpreter.preposition(gf_node).to_s
    # relation of anchor noun to governing verb not covered by "gfs" method
    #     when "verb+beyond-s"
    #       return "SB-of"

    #     when "verb+beyond-vp"
    #       return "OA-of"

    #     when "verb+beyond-pp-vp"
    #       return "MO-of"
    else
      return nil
    end
  end


  ###
  # given an anchor node and another node that may be some
  # grammatical function of the anchor node:
  # return the grammatical function (string) if found,
  # else nil.
  #
  # here: anchor node is adjective.
  def CollinsTntInterpreter.gf_adj(anchor_node,  # SynNode
                                   gf_node)      # SynNode

    # first classification: according to constituent type
    cat = CollinsTntInterpreter.category(gf_node)
    if cat.nil?
      return nil
    end

    # second classification: according to path
    path = CollinsTntInterpreter.path_between(anchor_node, gf_node)
    if path.nil?
      # no path between anchor node and gf node
      return nil
    end

    path.set_cutoff_last_pt_on_printing(true)
    path_string = path.print(true,false,true)

    case path_string
    when /^(U ADJP )?U NPB D $/
      categ2 = "nnpath"
    when "U ADJP D "
      categ2 = "adjp-neighbor"
    when /^(U ADJP )?U (VP U )?S(BAR)? D $/
      categ2 = "s"
    when /^U (ADJP U )?VP D $/
      categ2 = "vp"
    else
      categ2 = ""
    end

    # now evaluate based on both
    case cat + "+" + categ2
    when "noun+nnpath"
      return "HD"
    when "verb+adjp-neighbor"
      return "OC"
    when "prep+vp", "prep+adjp-neighbor"
      return "MO-" + CollinsTntInterpreter.preposition(gf_node).to_s
    else
      return nil
    end
  end

  ####
  # auxiliary of prune?:
  #
  # given a node and a hash mapping node IDs to paths to target:
  # Does that node have a sister that is a coordination and that
  # is between it and the target?
  #
  def CollinsTntInterpreter.conj_sister_between?(node, # SynNode
                                                 paths_to_target, # Hash: node ID -> Path obj: path from node to target
                                                 ti)  # hash: terminal node -> word index in sentence

    # does node have sisters that represent coordination?
    unless (p = node.parent())
      return false
    end

    unless (conj_sisters = p.children.select { |sib|
              sib != node and CollinsTntInterpreter.category(sib) == "con"
            } ) and
          not (conj_sisters.empty?)
      return false
    end

    # represent each coordination sister, and the node itself,
    # as a triple [node, leftmost terminal index(node), rightmost terminal index(node)
    conj_sisters = conj_sisters.map { |n|
      [n, CollinsTntInterpreter.lti(n, ti), CollinsTntInterpreter.rti(n, ti)]
    }

    this_triple = [node, CollinsTntInterpreter.lti(node, ti), CollinsTntInterpreter.rti(node, ti)]

    # sisters closer to the target than node:
    # also map to triples
    sisters_closer_to_target = p.children.select { |sib|
      sib != node and
        not(conj_sisters.include? sib) and
        paths_to_target[sib.id()] and
        paths_to_target[sib.id()].length() < paths_to_target[node.id()].length
    }.map { |n|
      [n, CollinsTntInterpreter.lti(n, ti), CollinsTntInterpreter.rti(n, ti)]
    }

    if sisters_closer_to_target.empty?
      return false
    end

    # is there any coordination sister that is inbetween this node
    # and some sister that is closer to the target?
    # if so, return true
    conj_sisters.each { |conj_triple|
      if leftof(conj_triple, this_triple) and
        sisters_closer_to_target.detect { |s| CollinsTntInterpreter.leftof(s, conj_triple) }

        return true

      elsif rightof(conj_triple, this_triple) and
           sisters_closer_to_target.detect { |s| CollinsTntInterpreter.rightof(s, conj_triple) }

        return true
      end
    }

    # else return false
    return false
  end

  ###
  # lti, rti: terminal index of the leftmost/rightmost terminal of
  # a given node (SynNode)
  #
  # auxiliary of conj_sister_between?
  def self.lti(node, # SynNode
                                terminal_index) # hash: terminal node -> word index in sentence
    lt = CollinsTntInterpreter.leftmost_terminal(node)
    unless lt
      return nil
    end

    return terminal_index[lt]
  end

  def self.rti(node, # SynNode
                                terminal_index) # hash: terminal node -> word index in sentence
    rt = CollinsTntInterpreter.rightmost_terminal(node)
    unless rt
      return nil
    end

    return terminal_index[rt]
  end

  ###
  # leftof, rightof: given 2 triples
  # [node(SynNode), index of leftmost terminal(integer/nil), index of rightmost terminal(integer/nil),
  #
  # auxiliaries of conj_sister_between?
  #
  # return true if both leftmost and rightmost terminal indices of the first triple are
  # smaller than (for leftof) / bigger than (for rightof) the
  # corresponding indices of the second triple
  #
  # return false if some index is nil
  def self.leftof(triple1, triple2)
    _dummy, lm1, rm1 = triple1
    _dummy, lm2, rm2 = triple2

    if lm1.nil? or rm1.nil? or lm2.nil? or rm2.nil?
      return false
    elsif lm1 < lm2 and rm1 < rm2
      return true
    else
      return false
    end
  end

  def self.rightof(triple1, triple2)
    _dummy, lm1, rm1 = triple1
    _dummy, lm2, rm2 = triple2

    if lm1.nil? or rm1.nil? or lm2.nil? or rm2.nil?
      return false
    elsif lm1 > lm2 and rm1 > rm2
      return true
    else
      return false
    end
  end
end
