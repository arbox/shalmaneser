# coding: utf-8
# require 'common/SalsaTigerRegXML'
require 'common/ruby_class_extensions'
# @todo Delete the module and include all methods on the class level
#       into the Tiger class.
# @note This class is used in Frappuccino, move it from the common library.
# @todo Investigate the dependency between this class and STXML.
#       Probably they can be combined.

#############################################
#
# max. projection:
#
# consists of methods that are 'building blocks' for computing
# the maximum projection of a verb in TIGER syntax
#
# basically, computing the max. projection is about moving an
# upper node upward. At the beginning it is the parent of the
# terminal node for the verb, and each building block moves it up
# to its parent, if the building block matches.
#
# Apart from the upper node, a lower node is also watched. At the
# beginning it is the terminal node for the verb, later it is usually
# the 'HD' child of the upper node. This lower node is needed for
# testing whether a building block matches.
#
# For handling conjunction, the upper node is split into two, a 'lower upper'
# and an 'upper upper' node. The 'lower upper' is used when some relation
# between the upper node and its descendants is tested, and the 'upper upper'
# is used when some relation between the upper node and its predecessors
# is tested. Usually the 'lower upper' and the 'upper upper' are the same,
# but conjunction building blocks move the 'upper upper' up to its parent
# while leaving the 'lower upper' unchanged.
#
# So all building block methods take three arguments: lower, upper_l and
# upper_u. All three are nodes given as SalsaTigerSentence objects
#
# All building block methods give as their return value a list of three
# nodes: [new_lower, new_upper_l, new_upper_u], if the building block
# matched. If it does not match, nil is returned.
#
# The method explain describes all building blocks,
# the conditions for the building blocks matching, and shows
# where the lower and the upper nodes will be after a building block matched.
#
# building blocks:
#  pp_pp
#  pp_fin
#  inf_fin
#  vzinf_fin
#  cvzinf_fin
#  modal
#  othermodal
#  conj
#
# To compute the maximal projection of a verb,
# we start at the parent of the terminal node for the verb
# "and move upwards.
# "The move upwards is broken up in little building blocks."
# "Each of them licenses one step upward in the syntactic tree."
#
# "Each building block needs information about two nodes:"
# "The current upper node (at the beginning, that is"
# "the parent of the terminal node for the verb) and"
# "one specific child of that current upper node"
# "(at the beginning, that is the terminal node for the verb)."
#
# "Each building block provides information of"
# "- where the new upper node is, depending on the current"
# "  upper node, and"
# "- where the new specific child is."
#
# "For handling conjunction, we need to complicate this picture somewhat:"
# "We split the current upper node into an 'upper upper'"
# "and a 'lower upper' node."
# "If we want to check the edge from the current upper node upwards,"
# "we use the 'upper upper'."
# "If we want to check an edge from the current upper node downwards,"
# "we use the 'lower upper'."
# "Almost always, the 'lower upper' and the 'upper upper' will be the same."
# "Except for the building block for conjunction:"
# "It moves the 'upper upper' one level up,"
# "but leaves the 'lower upper' the same."
#
# "There are five levels of building blocks."
#
# "* 1st level: auxiliary verb constructions involving a participle"
# " The following building blocks are tried, in this order:"
# " CONJ, PP-PP, CONJ, PP_FIN"
#
# "* 2nd level: infinitive constructions"
# " The following building blocks are tried, in this order:"
# " CONJ, INF-FIN, VZINF-FIN, CVZINF-FIN"
#
# "* 3rd level: modals"
# " The following building blocks are tried, in this order:"
# " CONJ, MODAL, OTHERMODAL"
#
# "* 4th level = 1st level"
#
# "* 5th level = 2nd level"
#
#
# "***These are the building blocks:"
#
# "PP-PP"
# "             VP (new uppermost node)"
# "           / | \\OC"
# "        HD/  |   VP|CVP (current uppermost node)"
# "         /   |    |"
# "        o    FE   |HD|CJ"
# "POS: V[AMV]PP     |"
# " new target     current target"
# "                  POS: V[AMV]PP"
#
# "PP-FIN"
# "             S/VP (new uppermost node)"
# "           / | \\OC or PD"
# "        HD/  |   VP|CVP|CO (current uppermost node)"
# "         /   |    |"
# "        o    FE   |HD|CJ"
# "POS: V[AMV]FIN    |"
# "     V[AMV]INF  current target"
# "or CAT: VZ        POS: V[AMV]PP"
#
# "INF_FIN"
# "             S/VP (new uppermost node)"
# "           / | \\OC"
# "        HD/  |   VP|CVP (current uppermost node)"
# "         /   |    |"
# "        o    FE   |HD|CJ"
# "POS: VAFIN        |"
# "     VAINF       current target"
# "     VVINF        POS: V[AMV]INF"
# "    new target"
#
# "VZINF-FIN"
# "             S/VP (new uppermost node)"
# "           / | \\OC"
# "        HD/  |   VP (current uppermost node)"
# "         /   |    |"
# "        o    FE   |HD"
# "POS: V[AV]FIN     |"
# "   new target    current target"
# "                  CAT: VZ"
#
# "CVZINF-FIN"
# " S/VP (new uppermost node)"
# " | \\OC"
# " |   CVP (current uppermost node)"
# " |    |"
# " FE   |CJ"
# "      |"
# "     current and new target"
# "     CAT: VZ"
#
# "MODAL"
# "             S/VP (new uppermost node)"
# "           / | \\OC"
# "        HD/  |   VP|CVP (current uppermost node)"
# "         /   |    |"
# "        o    FE   |HD|CJ"
# "      POS:        |"
# "  VM(PP|FIN|INF)  current target"
# "   new target     POS: V[AMV]INF"
#
# "OTHERMODAL"
# "             S/VP (new uppermost node)"
# "           / | \\OC"
# "        HD/  |   VP (current uppermost node)"
# "         /   |   | \\"
# "        o    FE  |HD \\OC"
# "POS: VMFIN       |    \\"
# "     VMINF      POS:    current target"
# "     VMPP     V[AMV]INF   POS: V[AMV]PP"
# "  new target  V[AMV]FIN"
#
# "CONJ"
# "  CVP (new upper uppermost node)"
# "   | \\CJ"
# "   |   VP (current and new uppermost node)"
# "   |    |"
# "   FE   |"
# "        |"
# "   current and new target"
###
module TigerMaxProjection

  def max_projection(node)
    parent = node.parent
    # node has no parent? recover somehow
    if parent.nil?
      return {'max_proj' => node,
              'max_proj_at_level' => [node]}
    end

    maxproj_at_level = Array.new
    maxproj_at_level << parent

    lower = node
    upper_u = upper_l = parent

    lower, upper_l, upper_u = project_participle(lower, upper_l, upper_u)
    maxproj_at_level << upper_u

    lower, upper_l, upper_u = project_infinitive(lower, upper_l, upper_u)
    maxproj_at_level << upper_u

    lower, upper_l, upper_u = project_modal(lower, upper_l, upper_u)
    maxproj_at_level << upper_u

    lower, upper_l, upper_u = project_participle(lower, upper_l, upper_u)
    maxproj_at_level << upper_u

    lower, upper_l, upper_u = project_infinitive(lower, upper_l, upper_u)
    maxproj_at_level << upper_u

    return {'max_proj' => upper_u,
            'max_proj_at_level' => maxproj_at_level}
  end


  ###
  def test_localtrees(path)
    # HIER WEITER: was genau passiert hier?
    retv = {}

    # test each step
    path.each { |step|
      retv = test_step(step, retv)

      if retv.nil?
        return nil
      end
    }

    # return result of last step
    return retv
  end

  ######
  private

  ###
  def test_step(path, previous)
    if path['from'].nil? or path['to'].nil? or path['edge'].nil?
      $stderr.puts 'TigerAux error: missing path hash entry'
      exit 1
    end

    from_node, *from_descr = path['from']
    to_node, *to_descr = path['to']

    # using the special flags tp_prev_to and tp_prev_from,
    # a node can also be set to be the value in the
    # 'previous' hash
    from_node = cf_previous(from_node, previous)
    to_node = cf_previous(to_node, previous)

    # test if 'from' node description matches
    unless test_node(from_node, from_descr)
      return nil
    end

    # try path
    direction, edgelabel = path['edge']
    case direction
    when 'up'
      label = from_node.parent_label()
      if label =~ edgelabel
        end_nodes = [from_node.parent()]
      else
        end_nodes = []
      end
    when 'dn'
      end_nodes = []
      from_node.each_child { |child|
        if child.parent_label() =~ edgelabel
          end_nodes << child
        end
      }
    else
      $stderr.puts 'TigerAux error: unknown direction'
      exit 1
    end

    # check all prospective end nodes
    remaining_end_nodes = end_nodes.select { |prosp_to_node|
      if to_node.nil? or to_node == prosp_to_node
        test_node(prosp_to_node, to_descr)
      else
        false
      end
    }

    if remaining_end_nodes.empty?
      return nil
    else
      return {'from' => from_node,
          'to' => remaining_end_nodes}
    end
  end

  ###
  def test_node(node, descr)

    cat_or_pos, pattern = descr
    if node.nil?
      $stderr.puts 'TigerAux error: test_node nil'
      exit 1
    end

    case cat_or_pos
    when 'pos'
      if node.part_of_speech =~ pattern
        return true
      else
        return false
      end
    when 'cat'
      if node.category =~ pattern
        return true
      else
        return false
      end
    when nil
      return true
    else
      $stderr.puts 'TigerAux error: neither cat nor pos'
      exit 1
    end
  end

  ###
  def cf_previous(node, previous)
    case node
    when 'tp_prev_to'
      return previous['to'].first
    when 'tp_prev_from'
      return previous['from']
    else
      return node
    end
  end

  ###
  def project_participle(lower, upper_l, upper_u)
    return project_this(lower, upper_l, upper_u,
                              [self.method('conj'),
                               self.method('pp_pp'),
                               self.method('conj'),
                               self.method('pp_fin')])
  end

  ###
  def project_infinitive(lower, upper_l, upper_u)
    return project_this(lower, upper_l, upper_u,
                        [self.method('conj'),
                         self.method('inf_fin'),
                         self.method('vzinf_fin'),
                         self.method('cvzinf_fin')
                        ])
  end

  ###
  def project_modal(lower, upper_l, upper_u)
    return project_this(lower, upper_l, upper_u,
                        [self.method('conj'),
                         self.method('modal'),
                         self.method('othermodal')
                        ])
  end

  ###
  def project_participle_(lower, upper_l, upper_u)
    return project_this(lower, upper_l, upper_u,
                              [self.method('conj'),
                               self.method('pp_pp'),
                               self.method('conj'),
                               self.method('pp_fin')])
  end

  ###
  def project_this(lower, upper_l, upper_u, method_list)
    method_list.each { |method|
      retv = method.call(lower, upper_l, upper_u)
      unless retv.nil?
        lower, upper_l, upper_u = retv
      end
    }
    return [lower, upper_l, upper_u]
  end

  ###
  def pp_pp(lower, upper_l, upper_u)

    retv =
          test_localtrees([
                            {'from' => [lower, 'pos', /^V[AMV]PP$/],
                             'to' => [upper_l, 'cat', /^C?VP$/],
                             'edge' => ['up', /^(HD)|(CJ)$/]},
                            {'from' => [upper_u, 'cat', /^C?VP$/],
                             'to' => [nil, 'cat', /^VP$/],
                             'edge' => ['up', /^OC$/]},
                            {'from' => ['tp_prev_to', 'cat', /^VP$/],
                             'to' => [nil, 'pos', /^V[AMV]PP$/],
                             'edge' => ['dn', /^HD$/]}
                          ])

    if retv.nil?
      return nil
    else
      return [retv['to'].first, retv['from'], retv['from']]
    end
  end

  ###
  def pp_fin(lower, upper_l, upper_u)

    retv =
          test_localtrees([
                            {'from' => [lower, 'pos', /^V[AMV]PP$/],
                             'to' => [upper_l, 'cat', /^C?VP$/],
                             'edge' => ['up', /^(HD)|(CJ)$/]},
                            {'from' => [upper_u,'cat', /^C?VP$/],
                             'to' => [nil, 'cat', /^(VP)|S$/],
                             'edge' => ['up', /^(OC)|(PD)$/]}
                          ])

    if retv.nil?
      return nil
    end

    new_upper = retv['to'].first

    # test two alternatives:
    # head child of new_upper is either a VXFIN or VXINF terminal...
    retv =
          test_localtrees([
                            {'from' => [new_upper, 'cat', /^(VP)|S$/],
                             'to' => [nil, 'pos', /^V[AMV]((FIN)|(INF))$/],
                             'edge' => ['dn', /^HD$/]}
                          ])

    # ... or a VZ nonterminal
    if retv.nil?
      retv =
            test_localtrees([
                              {'from' => [new_upper, 'cat', /^(VP)|S$/],
                               'to' => [nil, 'cat', /^VZ$/],
                               'edge' => ['dn', /^HD$/]}
                            ])
    end

    if retv.nil?
      return nil
    else
      return [retv['to'].first, new_upper, new_upper]
    end
  end


  ###
  def inf_fin(lower, upper_l, upper_u)

    retv =
          test_localtrees([
                            {'from' => [lower, 'pos', /^V[AMV]INF$/],
                             'to' => [upper_l, 'cat', /^C?VP$/],
                             'edge' => ['up', /^(HD)|(CJ)$/]},
                            {'from' => [upper_u,'cat', /^C?VP$/],
                             'to' => [nil, 'cat', /^(VP)|S$/],
                             'edge' => ['up', /^OC$/]},
                            {'from' => ['tp_prev_to', 'cat', /^(VP)|S$/],
                             'to' => [nil, 'pos', /^(VAFIN)|(VAINF)|(VVINF)$/],
                             'edge' => ['dn', /^HD$/]}
                          ])
    if retv.nil?
      return nil
    else
      return [retv['to'].first, retv['from'], retv['from']]
    end
  end


  ###
  def vzinf_fin(lower, upper_l, upper_u)

    retv =
          test_localtrees([
                            {'from' => [lower, 'cat', /^VZ$/],
                             'to' => [upper_l, 'cat', /^VP$/],
                             'edge' => ['up', /^HD$/]},
                            {'from' => [upper_u,'cat', /^VP$/],
                             'to' => [nil, 'cat', /^(VP)|S$/],
                             'edge' => ['up', /^OC$/]},
                            {'from' => ['tp_prev_to', 'cat', /^(VP)|S$/],
                             'to' => [nil, 'pos', /^V[AV]FIN$/],
                             'edge' => ['dn', /^HD$/]}
                          ])

    if retv.nil?
      return nil
    else
      return [retv['to'].first, retv['from'], retv['from']]
    end
  end

  ###
  def cvzinf_fin(lower, upper_l, upper_u)

    retv =
          test_localtrees([
                            {'from' => [lower, 'cat', /^VZ$/],
                             'to' => [upper_l, 'cat', /^CVP$/],
                             'edge' => ['up', /^CJ$/]},
                            {'from' => [upper_u,'cat', /^CVP$/],
                             'to' => [nil, 'cat', /^(VP)|S$/],
                             'edge' => ['up', /^OC$/]}
                          ])

      if retv.nil?
        return nil
      else
        return [lower, upper_l, retv['to'].first]
      end
  end

  ###
  def modal(lower, upper_l, upper_u)

    retv =
          test_localtrees([
                            {'from' => [lower, 'pos', /^V[AMV]INF$/],
                             'to' => [upper_l, 'cat', /^C?VP$/],
                             'edge' => ['up', /^(HD)|(CJ)$/]},
                            {'from' => [upper_u,'cat', /^C?VP$/],
                             'to' => [nil, 'cat', /^(VP)|S$/],
                             'edge' => ['up', /^OC$/]},
                            {'from' => ['tp_prev_to', 'cat', /^(VP)|S$/],
                             'to' => [nil, 'pos', /^VM((PP)|(FIN)|(INF))$/],
                             'edge' => ['dn', /^HD$/]}
                          ])

    if retv.nil?
      return nil
    else
      return [retv['to'].first, retv['from'], retv['from']]
    end
  end

  ###
  def othermodal(lower, upper_l, upper_u)

    retv =
          test_localtrees([
                            {'from' => [lower, 'pos', /^V[AMV]PP$/],
                             'to' => [upper_l, 'cat', /^VP$/],
                             'edge' => ['up', /^OC$/]},
                            {'from' => [upper_l, 'cat', /^VP$/],
                             'to' => [nil, 'pos', /^V[AMV]((INF)|(FIN))$/],
                             'edge' => ['dn', /^HD$/]},
                            {'from' => [upper_u,'cat', /^VP$/],
                             'to' => [nil, 'cat', /^(VP)|S$/],
                             'edge' => ['up', /^OC$/]},
                            {'from' => ['tp_prev_to', 'cat', /^(VP)|S$/],
                             'to' => [nil, 'pos', /^VM((PP)|(FIN)|(INF))$/],
                             'edge' => ['dn', /^HD$/]}
                          ])

    if retv.nil?
      return nil
    else
      return [retv['to'].first, retv['from'], retv['from']]
    end
  end

  ###
  def conj(lower, upper_l, upper_u)

    retv = test_localtrees([
                             {'from' => [lower, nil, //],
                              'to' => [upper_l, 'cat', /^VP$/],
                              'edge' => ['up', //]},
                             {'from' => [upper_u,'cat', /^VP$/],
                              'to' => [nil, 'cat', /^CVP$/],
                              'edge' => ['up', /^CJ$/]}
                           ])

    if retv.nil?
      return nil
    else
      return [lower, upper_l, retv['to'].first]
    end
  end
end

require 'common/headz'
require 'frappe/syn_interpreter'

# @todo AB: [2015-12-16 Wed 00:05]
#   Rename this class to TigerInterpreter.
class Tiger < SynInterpreter

  extend TigerMaxProjection

  @@heads_obj = Headz.new()

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
  def Tiger.category(node) # SynNode
    pt = Tiger.pt(node)
    if pt.nil?
      # phrase type could not be determined
      return nil
    end

    case pt.to_s.strip()
    when /^C?ADJ/, /^PIS/, /^C?AP[^A-Za-z]?/ then return "adj"
    when /^C?ADV/, /^C?AVP/, /^PROAV/ then  return "adv"
    when /^CARD/  then return "card"
    when  /^C?KO/             then return "con"
    when /^PPOS/, /^ART/ ,/^PIAT/, /^PD/, /^PRELAT/, /^PWAT/ then return "det"
    when /^FM/ , /^XY/ then return "for"
    when /^C?N/, /^PPER/, /^PN/, /^PRELS/, /^PWS/ then return "noun"
    when /^ITJ/ then return "sent"
    when  /^PRF/, /^PTK/, /^TRUNC/      then return "part"
    when  /^C?PP/ , /^APPR/, /^PWAV/      then return "prep"
    when /^\$/ then return "pun"
    when /^C?S$/, /^CO/, /^DL/, /^CH/, /^ISU/  then return "sent" # I don't like to put CO/DL in here, but where should they go?
    when /^TOP/                then return "top"
    when /^C?V/               then return "verb"
    else
      #      $stderr.puts "WARNING Unknown category/POS "+c.to_s+" (German data)"
      return nil
    end
  end

  ###
  # is relative pronoun?
  #
  def Tiger.relative_pronoun?(node) # SynNode
    pt = Tiger.pt(node)
    if pt.nil?
      # phrase type could not be determined
      return nil
    end

    case pt.to_s.strip()
    when /^PREL/, /^PWAV/,  /^PWAT/
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
  # returns: string or nil
  def Tiger.lemma_backoff(node)
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
  # verb_with_particle:
  #
  # given a node and a nodelist,
  # if the node represents a verb:
  # see if the verb has a particle among the nodes in nodelist
  # if so, return it
  def Tiger.particle_of_verb(node,           # SynNode
                             node_list)      # array: SynNode

    # must be verb
    unless Tiger.category(node) == "verb"
      return nil
    end

    # must have parent
    unless node.parent
      return nil
    end

    particles = node.parent.children.select { |sister|
      # look for sisters of the verb node that are in node_list
      node_list.include? sister
    }.select { |sister|
      # see if its incoming edge is labeled "SVP"
      sister.parent_label() == "SVP"
    }.reject { |particle|
      # Sleepy parser problem: it often tags ")" as a separate verb particle
      particle.get_attribute("lemma") == ")" or
        particle.word == ")"
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
  # default: no recognition of auxiliaries
  def Tiger.auxiliary?(node)
    if node.part_of_speech() and
        node.part_of_speech =~ /^VA/
      return true
    else
      return false
    end
  end

  ###
  # modal?
  #
  # returns true if the given node is a modal verb
  #
  # returns: boolean
  def Tiger.modal?(node)
    if node.part_of_speech() and
        node.part_of_speech =~ /^VM/
      return true
    else
      return false
    end
  end

  ###
  # head_terminal
  #
  # given a constituent, return the terminal node
  # that describes its headword
  # default: a heuristic that assumes the existence of a 'head'
  #   attribute on nodes:
  #   find the first node in my yield corresponding to my head attribute.
  # add-on: if this doesn't work, ask the headz package for the head
  #
  # returns: a SynNode object if successful, else nil
  def Tiger.head_terminal(node)
    if (head = super(node))
      return head
    end

    head_hash = @@heads_obj.get_sem_head(node)
    if head_hash.nil?
      return nil
    elsif head_hash["prep"]
      return head_hash["prep"]
    else
      return head_hash["head"]
    end
  end


  #####################################
  # verbs(sobj)  sobj is a sentence in SalsaTigerSentence format
  #
  # return a list of the nodes of full verbs in a given sentence:
  # it is a list of lists. An item in that list is
  # - either a pair [verb, svp]
  #   of the node of a verb with separable prefix
  #   and the node of its separate prefix
  # - or a singleton [verb]
  #   of the node of a verb without separate prefix
  def Tiger.verbs(sobj)
    return sobj.terminals().select { |t|
      # verbs

      Tiger.category(t) == "verb"
    }.map { |verb|

      # watch out for separate verb prefixes
      parent = verb.parent
      if parent.nil?
        # verb is root node, for whatever reason
        [verb]
      else

        svp_children = parent.children_by_edgelabels(['SVP'])
        if svp_children.empty?
          # verb has no separate verb prefix
          [verb]
        elsif svp_children.length == 1
          # verb has exactly one separate verb prefix
          [verb, svp_children.first]
        else
          # more than one separate verb prefix? weird.
          $stderr.print 'Tiger warning: more than one separate verb prefix '
          $stderr.print 'for node ', verb.id, "\n"
          [verb, svp_children.first]
        end
      end
    }
  end

  ###
  # preposition
  #
  # if the given node represents a PP, return the preposition (string)
  def Tiger.preposition(node) # SynNode
    hash = @@heads_obj.get_sem_head(node)
    if hash and hash["prep"]
      return hash["prep"].to_s
    end

    # this didn't work, try something else: first preposition among my terminals
    pnode = node.terminals_sorted().detect { |n|
      Tiger.category(n) == "prep"
    }
    if pnode
      return pnode.word()
    else
      return nil
    end
  end


  ###
  # voice
  #
  # given a constituent, return
  # - "active"/"passive" if it is a verb
  # - nil, else
  def Tiger.voice(node)

    unless Tiger.category(node) == "verb"
      return nil
    end

    # node is a participle linked to its VP or S parent by HD or CJ
    retv = test_localtrees([ {'from' => [node, 'pos', /^V[AMV]PP$/],
                              'to' => [nil, 'cat', /^(CVP)|(VP)|S|(CS)$/],
                              'edge' => ['up', /^(HD)|(CJ)$/]}])

    if retv
      verb_parent = retv['to'].first

      # coordination?
      retv = test_localtrees([{'from' => [verb_parent, nil, //],
                             'to' => [nil, 'cat', /^CVP$/],
                             'edge' => ['up', /^CJ$/]}])
      if retv

        # yes, coordination
        #   S/VP
        #    |OC
        #   CVP
        #    | CJ
        #   VP
        #    | HD
        # participle

        cvp = retv['to'].first

        retv = test_localtrees([{'from' => [cvp, nil, //],
                             'to' => [nil, 'cat', /^S|(VP)$/],
                             'edge' => ['up', /^OC$/]}])

      else
        # node's parent is linked to its parent via an OC edge
        retv = test_localtrees([{'from' => [verb_parent, nil, //],
                                   'to' => [nil, 'cat', /^(VP)|S$/],
                                   'edge' => ['up', /^OC$/]}])
      end

      if retv.nil?
        return "active"
      end

      verb_grandparent = retv['to'].first

    else
      # KE Dec 19: test whether the participle
      # is linked to its parent via an OC edge.
      # if so, it has the same  function as the
      # verb_grandparent above

      # node is a participle linked to its VP or S parent by OC
      retv = test_localtrees([ {'from' => [node, 'pos', /^V[AMV]PP$/],
                              'to' => [nil, 'cat', /^(CVP)|(VP)|S|(CS)$/],
                              'edge' => ['up', /^OC$/]}])

      if retv
        verb_grandparent = retv['to'].first

      else
        # this test has failed
        return "active"
      end
    end

    #puts test_localtrees([{'from' => [verb_grandparent, nil, //],
    #                         'to' => [nil, 'pos', /^VA.*$/],
    #                         'edge' => ['dn', /^HD$/]}])

    # node's grandparent has a HD child that is a terminal node, an auxiliary
    retv = test_localtrees([{'from' => [verb_grandparent, nil, //],
                             'to' => [nil, 'pos', /^VA.*$/],
                             'edge' => ['dn', /^HD$/]}])

    if retv.nil?
      return "active"
    end

    # that HD child is a form of 'werden'
    may_be_werden = retv['to'].first

    unless may_be_werden.part_of_speech() =~ /^VA/
      return "active"
    end

    # no morphology, so approximate it using regexp.s
    case may_be_werden.word
    when "geworden"
    when /^w.+rd(e|en|et|st|est)?$/
    else
      return "active"
    end

    # all tests passed successfully
    return "passive"
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
  def Tiger.gfs(node,   # SynNode object
                sent)   # SalsaTigerSentence object

    case Tiger.category(node)
    when "adj"
      return Tiger.gfs_adj(node)
    when "noun"
      return Tiger.gfs_noun(node, sent)
    when "verb"
      return Tiger.gfs_verb(node)
    else
      return []
    end
  end


  ###
  # informative_content_node
  #
  # for most constituents: nil
  # for a PP, the NP
  # for an SBAR, the VP
  # for a VP, the embedded VP
  def Tiger.informative_content_node(node)
    this_pt = Tiger.simplified_pt(node)

    unless ["S", "CS", "VP", "CVP", "PP", "CPP"].include? this_pt
      return nil
    end

    nh = Tiger.head_terminal(node)
    unless nh
      return nil
    end
    headlemma = Tiger.lemma_backoff(nh)

    nonhead_children = node.children().reject { |n|
      nnh = Tiger.head_terminal(n)
      not(nnh) or
        Tiger.lemma_backoff(nnh) == headlemma
    }
    if nonhead_children.length() == 1
      return nonhead_children.first
    end

    # more than one child:
    # for SBAR and VP take child with head POS starting in VB,
    # for PP child with head POS starting in NN
    case this_pt
    when /^C?S/, /^C?VP/
      icont_child = nonhead_children.detect { |n|
        h = Tiger.head_terminal(n)
        h and h.part_of_speech() =~ /^V/
      }
    when /^C?PP/
      icont_child = nonhead_children.detect { |n|
        h = Tiger.head_terminal(n)
        h and h.part_of_speech() =~ /^N/
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

  ###
  # main node of expression
  #
  # second argument non-nil:
  # don't handle multiword expressions beyond verbs with separate particles
  #
  # returns: SynNode, main node, if found
  # else nil
  def Tiger.main_node_of_expr(nodelist,
                              no_mwes = nil)

    # map nodes to terminals
    nodelist = nodelist.map { |n| n.yield_nodes() }.flatten

    # do we have a list of length 2,
    # one member being "zu", the other a verb, with a common parent "VZ"?
    # then return the verb
    if nodelist.length() == 2
      zu, verb = nodelist.distribute { |n| n.part_of_speech() == "PTKZU" }
      if zu.length() == 1 and
          Tiger.category(verb.first) == "verb" and
          verb.first.parent == zu.first.parent and
          verb.first.parent.category() == "VZ"
        return verb.first
      end
    end

    # no joy: try method offered by abstract class
    return super(nodelist, no_mwes)
  end


  ########
  # prune?
  # given a target node t and another node n of the syntactic structure,
  # decide whether n is likely to instantiate a semantic role
  # of t. If not, recommend n for pruning.
  #
  # This method implements a slight variant of Xue and Palmer (EMNLP 2004).
  # Pruning according to Xue & Palmer, EMNLP 2004.
  # "Step 1: Designate the predicate as the current node and
  #    collect its sisters (constituents attached at the same level
  #    as the predicate) unless its sisters are coordinated with the
  #    predicate.
  #
  #  Step 2: Reset the current node to its parent and repeat Step 1
  #    till it reaches the top level node.
  #
  # Modifications made here:
  # - paths of length 0 accepted in any case
  # - TIGER coordination allowed (phrase types CX)
  #
  # returns: false to recommend n for pruning, else true
  def Tiger.prune?(node, # SynNode
                   paths_to_target, # hash: node ID -> Path object: paths from nodes to target
                   terminal_index)  # hash: terminal node -> word index in sentence

    path_to_target = paths_to_target[node.id()]

    if not path_to_target
      # no path from target to node: suggest for pruning
      return 0
    elsif path_to_target.length == 0
      # target may be its own role: definite accept
      return 1
    else
      # consider path from target to node:
      # (1) If the path to the current node includes at least one Up
      # and exactly one Down, keep.
      # (2) If the parth to the current node includes at least one Up
      # and two Down and the roof node is a C-something, keep (coordination).
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

      if num_up >= 1 and num_down == 1
        # case (1)
        return  1
      elsif num_up >= 1 and num_down == 2 and CollinsTntInterpreter.category(path_to_target.lca()) =~ /^C/
        # case (2)
        return 1
      else
        # case (3)
        return 0
      end
    end
  end


  ################################
  private
  ################################

  ###
  def Tiger.subject(verb_node)

    unless Tiger.category(verb_node) == "verb"
      return nil
    end

    if Tiger.voice(verb_node) == "passive"
      # passive: then what we would like to return as subject
      # is the SBP sibling of this verb

      parent = verb_node.parent

      if parent.nil?
        # verb_node seems to be the root, strangely enough
        return []
      end
      return parent.children_by_edgelabels(['SBP'])

    else
      # not passive: then the subject of the verb
      # is actually its subject in this sentence

      # needed???
      # return if there is no surface subject
      # e.g. parser errors like ADJD => VVPP

      return Tiger.surface_subject(verb_node)
    end

  end


  ###
  def Tiger.direct_object(verb_node)

    unless Tiger.category(verb_node) == "verb"
      return nil
    end

    if Tiger.voice(verb_node) == "passive"
      # passive: then what we would like to return as direct object
      # is the subject of this verb
      return Tiger.surface_subject(verb_node)
    else

      # not passive: then the direct object
      # is an OA sibling of the node verb_node
      parent = verb_node.parent

      if parent.nil?
        # verb_node seems to be the root, strangely enough
        return []
      end

      return parent.children_by_edgelabels(['OA'])
    end
  end

  ###
  def Tiger.dative_object(verb_node)

    unless Tiger.category(verb_node) == "verb"
      return nil
    end

    parent = verb_node.parent

    if parent.nil?
      return []
    end

    return parent.children_by_edgelabels(['DA'])
  end

  ###
  def Tiger.prep_object(verb_node, preposition)

    unless Tiger.category(verb_node) == "verb"
      return nil
    end

    parent = verb_node.parent()
    if parent.nil?
          # verb_node seems to be the root, strangely enough
      return []
    end

    # find all PPs that are siblings of verb_node
    pps = []
    parent.each_child { |child|
      if child.category == 'PP'
        pps << child
      end
    }

    # now filter for those with the right preposition
    if preposition.nil?
      return pps
    else
      return pps.find_all { |node|
        # prepositions are AC children of PP nodes
        node.children_by_edgelabels(['AC']).map { |prep_node|
          # prepositions are terminal words
          prep_node.word()
          # we are interested in those that match the parameter 'preposition'
        }.include? preposition
      }
    end
  end

  ###
  def Tiger.surface_subject(verb_node)

    max_proj = Tiger.max_projection(verb_node)
    # test each level in the computation of the maximal projection,
    # from the lowest (the parent of verb_node)
    # to the highest
    max_proj['max_proj_at_level'].each { |node|
      # test if this node has a SB child
      # if so, use it
      sb_children = node.children_by_edgelabels(['SB'])

      unless sb_children.empty?
        return sb_children
      end
    }
    return []
  end


  ##################
  # gfs_verb
  #
  # given a node (a SynNode object) that is a terminal node
  # representing a verb, determine
  # all grammatical functions of this verb
  # along with their head words
  #
  # verb_node: SynNode object, terminal node representing a verb
  #
  # returns: a list of pairs [relation(string), node(SynNode)]
  #  'relation' is 'SB', 'OA', 'DA', 'MO', 'OC'
  #  'node' is the constituent that stands in this relation to verb_node

  def Tiger.gfs_verb(verb_node)

    unless Tiger.category(verb_node) == "verb"
      return []
    end

    # construct a list of pairs [relation, node]
    nodes = Array.new
    # subjects:
    n_arr = Tiger.subject(verb_node)

    if n_arr.length() > 0
      nodes << ["SB", n_arr.first]
    end

    # direct object:
    n_arr = Tiger.direct_object(verb_node)
    if n_arr.length() > 0
      nodes << ["OA", n_arr.first]
    end

    # dative object:
    n_arr = Tiger.dative_object(verb_node)
    if n_arr.length() > 0
      nodes << ["DA", n_arr.first]
    end


    # pp objects and adjuncts:
    nodes.concat Tiger.prep_object(verb_node, nil).map { |n|
      unless (edgelabel = n.parent_label)
        edgelabel = "MO"
      end
      [edgelabel + "-" + Tiger.preposition(n).to_s, n]
    }

    # sentence complement:
    # verb node's parent has an OC child
    parent = verb_node.parent
    unless parent.nil?
      parent.children_by_edgelabels(["OC"]).each { |n|
        nodes << ["OC", n]
      }
    end

    return nodes
  end

  ###
  # gfs_noun
  #
  # determine relation names and relation-bearing syntax nodes
  # for noun targets
  #
  # returns: a list of pairs
  # [rel(string), node(SynNode)]
  def Tiger.gfs_noun(noun_node, # SynNode object: terminal, noun
                     sent_obj)  # SalsaTigerSentence object: sentence in which this noun occurs


    # construct a list of pairs [relation, node]
    retv = Array.new

    ##
    # determine noun-noun relations:
    #  (1) edge label leading to this node is NK, and
    #     parent of this node has child with edge label not NK
    #     then: that child
    #  (2) or parent of this node is NP/PP, the grandparent is NP,
    #     and parent and grandparent are not linked by an NK edge
    #     then: the grandparent
    #   (3) or grandparent of this node is CNP
    #     then: that CNP's other children
    parent = noun_node.parent()
    np_pp_labels_without_cnp = ["NP", "PP", "PN"]
    np_pp_labels = ["NP", "PP", "PN", "CNP"]

    if parent and
        noun_node.parent_label() == "NK"
      # (1)
      parent.children().select { |n|
        n.parent_label() != "NK"
      }.each { |n|
        unless n == noun_node

          retv << [n.parent_label(), n]
        end
      }
    end

    # (2)
    if parent
      grandparent = parent.parent()
    end

    if parent and grandparent and
        np_pp_labels.include? parent.category() and
        np_pp_labels_without_cnp.include? grandparent.category() and
        parent.parent_label() != "NK"

        retv << [parent.parent_label(), grandparent]
    end

    # (3)
    if parent and grandparent and
        grandparent.category() == "CNP"

      grandparent.each_child() { |n|
        if np_pp_labels.include? n.category() and
            n != parent

          retv << ["CJ", n]
        end
      }
    end

    return retv
  end

  ###
  # gfs_adj
  #
  # determine relation names and relation-bearing syntax nodes
  # for adjective targets
  #
  # returns: a list of pairs
  # [rel(string), node(SynNode)]
  #
  # although in this case it's just one pair (if we can find it),
  # describing the head noun
  def Tiger.gfs_adj(adj_node) # SynNode object: terminal, adjective

    parent = adj_node.parent()

    if parent.nil?
      return []
    end

    if ["NP", "CNP", "PP", "CPP", "PN"].include? parent.category
      return [["HD", parent]]
    else
      return []
    end
  end
end
