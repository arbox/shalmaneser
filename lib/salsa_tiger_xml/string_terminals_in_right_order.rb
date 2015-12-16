#########
# module StringTerminalsInRightOrder
#
# returns the yield of a node, or a list of nodes, as a string
# of " "-separated words
#
# Words are put into the right order, left to right,
# under the assumption that their node IDs reflect that order
#
# Terminal nodes are assumed to have IDs ending in a number,
# numbered from left to right
#
# Splitword nodes are assumed to have IDs ending in N_sM
# for numbers N and M, where N orders terminals left to right
# and M orders the splitword parts left to right
#
# If the yield of the node/the list of nodes contains all splitwords of a terminal,
# the whole terminal is taken instead
#
# methods:
#
# string_for_node  returns the string for the yield of a node
#     node: a node object
#
# string_for_nodes returns the string for the yield of a list of nodes
#     nodes: a list of node objects

module StringTerminalsInRightOrder
  def string_for_node(node)
    string_for_nodes([node])
  end

  def string_for_nodes(nodes)
    a = right_level_terminals_for_nodes(nodes)
    a = sort_terminals_and_splitwords_left_to_right(a)
    return node_array_to_string(a)
  end

  #####
  private

  # right_level_terminals_for_nodes:
  # - compute the yield for each element of 'nodes'
  # - then consider all splitwords in the yield:
  #   if all splitwords of a terminal are in the yield,
  #   then use the terminal rather than its splitwords
  def right_level_terminals_for_nodes(nodes)
    a = nodes.map { |n| n.yield_nodes}.flatten
    b = []
    a.each { |n|
      if n.is_splitword?
        # see if a contains all parts of this splitword
        # if so, take into b the splitword's parent, the terminal,
        # rather than the individual splitwords

        if n.parent.nil?
          # splitword without a parent
          b << n
        elsif b.include? n.parent or a.include? n.parent
          # did we already include the splitword's parent in b?
          # then we're done
        else

          # check if all children of n.parent are in 'a'
          all_in = true
          n.parent.each_child { |nsibling|
            unless a.include? nsibling
              all_in = false
              break
            end
          }

          if all_in
            # yes, all children of n.parent are in 'a'
            b << n.parent
          else
            # no, some sibling of n is not in 'a'
            b << n
          end
        end
      elsif n.is_terminal?
        # n is a terminal
        b << n
        # if n is anything but a splitword or a terminal,
        # ignore it
      end
    }
    return b.uniq
  end

  # sort_terminals_and_splitwords_left_to_right:
  # take an array of nodes that consists of terminals and splitwords
  # and sort them using the following comparison:
  # - when comparing two terminals, use the
  #   last numbers in their respective IDs
  # - when comparing two splitwords, their IDs end in _N_sM
  #   for numbers N and M.
  #   If they coincide in N, compare them by M,
  #   else compare them by M
  # - when comparing a terminal and a splitword,
  #   compare the terminal's last number to the splitword's N
  def sort_terminals_and_splitwords_left_to_right(nodes)
    nodes.sort { |a, b|
      if a.is_splitword? and b.is_splitword?
        compare_splitwords(a, b)
      elsif a.is_terminal? and b.is_terminal?
        compare_terminals(a, b)
      else
        compare_mixed(a, b)
      end
    }
  end

  # node_array_to_string:
  # 'nodes' is an array of node objects, each of which offer a "word" method
  # string their words together separated by " "
  def node_array_to_string(nodes)
    s = ""
    nodes.each { |n|
      s = s + n.word + " "
    }
    return s
  end

  # - when comparing two terminals, use the
  #   last numbers in their respective IDs
  def compare_terminals(a, b)
    last_i(a) <=> last_i(b)
  end

  # - when comparing two splitwords, their IDs end in _N_sM
  #   for numbers N and M.
  #   If they coincide in N, compare them by M,
  #   else compare them by M
  def compare_splitwords(a, b)
    if splitword_terminal_i(a) == splitword_terminal_i(b)
      # parts of same terminal?
      # compare parts
      last_i(a) <=> last_i(b)
    else
      # not parts of same terminal?
      # compare terminals
      splitword_terminal_i(a) <=> splitword_terminal_i(b)
    end
  end

  # - when comparing a terminal and a splitword,
  #   compare the terminal's last number to the splitword's N
  def compare_mixed(a, b)
    if a.is_splitword? and b.is_terminal?
      splitword_terminal_i(a) <=> last_i(b)

    elsif a.is_terminal? and b.is_splitword?
       last_i(a) <=> splitword_terminal_i(b)
    else
      # not one terminal, one splitword?
      # then what?
      $stderr.print "SalsaTigerSentence, compare_mixed: confused by "
      $stderr.print a.id, ",  ", b.id, "\n"
    end
  end

  # return last number of the ID of a node
  def last_i(n)
    n.id =~ /(\d+)$/ # match final string of digits
    if $1.nil? # if shouldn't happen _in principle_
               # but we might get weird node IDs for splitwords;
               # so we act gracefully and catch the case where there
               # is one final letter behind the digits
      n.id =~ /(\d+)\w$/
    end
    if $1.nil? # this shouldn't ever happen
      $stderr.print "SalsaTigerSentence, last_i: Couldn't extract digits from: "
      $stderr.print n.id, "\n"
      exit 1
    end
    return $1.to_i       # and return it as number
  end

  # assume the ID of the node includes N_sM
  # return N
  def splitword_terminal_i(n)
    n.id =~ /(\d+)_s\d*/ # match string of digits before splitword ID
    if $1.nil? # this shouldn't ever happen
      $stderr.print "SalsaTigerSentence, splitword_terminal_i: Couldn't extract digits from: "
      $stderr.print n.id, "\n"
      exit 1
    end
    return $1.to_i       # and return it as number
  end

end
