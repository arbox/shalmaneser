# GfInduce
# Katrin Erk Jan 2006
#
# Given parse trees with FrameNet frames assigned on top of the syntactic analysis,
# and given that the Frame Elements also contain information on grammatical function
# and phrase type (as e.g. in the FrameNet annotation),
# induce a mapping from parse tree paths to grammatical functions from this information
# and apply it to new sentences

require "ruby_class_extensions"

#####################################################################
# Management of mapping from GFs to paths
#####################################################################

class GfiGfPathMapping

  #########################################
  # Initialization
  #########################################

  ###
  def initialize(interpreter_class)

    @interpreter = interpreter_class

    # hash: POS(string) -> hash gf(string) -> hash: path_string -> frequency(int)
    @gf_to_paths = Hash.new

    # hash: POS(string)-> hash: gf(string) -> hash: one edge of a path ->
    #  frequency(int) | hash: one edge of a path -> ...
    @gf_to_edgelabel = Hash.new

    # hash: word(string) -> array: [gf, prep, head_category]
    @word_to_gflist = Hash.new

    # hash: path as string(string) -> array of steps
    # where a step is a tuple of stringss [{U, D}, edgelabel, nodelabel}
    @pathstring_to_path = Hash.new
  end

  #########################################
  # Storing induced mappings
  #########################################

  ###
  def store_mapping(gf,   # grammatical function: string
                    path, # Path object (from AbstractSynInterface)
                    node, # SynNode associated with GF and reached via path
                    lemma,# lemma: string
                    pos)  # part of speech: string

    path_s = path.print(true, true, true)
    lemmapos = string_lemmapos(lemma, pos)
    prep = @interpreter.preposition(node)
    if prep
      prep.downcase!
    end
    h = @interpreter.head_terminal(node)
    if h
      headcat = @interpreter.category(h)
    else
      headcat = nil
    end

    # remember the path as an array of triples [direction, edgelabel, nodelabel]
    # as hash value of the path-as-string
    unless @pathstring_to_path[path_s]
      @pathstring_to_path[path_s] = Array.new
      path.each_step { |direction, edgelabel, nodelabel, node|
        @pathstring_to_path[path_s] << [direction, edgelabel, nodelabel]
      }
    end

    # store the mapping in the
    # gf -> path hash
    unless @gf_to_paths[pos]
      @gf_to_paths[pos] = Hash.new
    end
    unless @gf_to_paths[pos][gf]
      @gf_to_paths[pos][gf] = Hash.new(0)
    end
    @gf_to_paths[pos][gf][path_s] = @gf_to_paths[pos][gf][path_s] + 1


    # remember this gf/pt tuple as possible GF of the current lemma
    unless @word_to_gflist[lemmapos]
      @word_to_gflist[lemmapos] = Array.new
    end
    unless @word_to_gflist[lemmapos].include? [gf, prep, headcat]
      @word_to_gflist[lemmapos] << [gf, prep, headcat]
    end
  end

  ###
  # finish up inducing:
  #  reencode information in a fashion
  #  that makes apply() faster
  def finish_inducing()
    # make sure gf_to_edgelabel is empty at the start
    @gf_to_edgelabel.clear()

    @gf_to_paths.each_pair { |pos, gf_to_paths_to_freq|
      unless @gf_to_edgelabel[pos]
        @gf_to_edgelabel[pos] = Hash.new()
      end

      gf_to_paths_to_freq.each_pair { |gf, paths_to_freq|
        paths_to_freq.each_pair { |pathstring, freq|

          steps = @pathstring_to_path[pathstring]
          if steps.nil? or steps.empty?
            # do not list empty paths
            $stderr.puts "found empty path for #{gf}, frequency #{freq}. Skipping."
            next
          end

          if freq >= 5 or
              gf =~ /Head|Appositive|Quant|Protagonist/
            # path frequent enough: list it

            unless @gf_to_edgelabel[pos][gf]
              @gf_to_edgelabel[pos][gf] = Hash.new()
            end

            enter_path(@gf_to_edgelabel[pos][gf], steps.clone(), freq)
          end
        }
      }
    }
  end

  #########################################
  # Test output
  #########################################

  ###
  # test output
  def test_output()
    # gf_to_paths:
    # sum frequencies, compare frequency against average path length
    puts "============================="
    puts "GF_TO_PATHS"
    puts "============================="
#     @gf_to_paths.each_key { |pos|
#       @gf_to_paths[pos].each_key { |gf|
#         puts "================"
#         puts "POS #{pos} GF #{gf}:"
#         @gf_to_paths[pos][gf].each_pair { |path_s, freq|
#           puts "#{path_s} freq:#{freq} len:#{@pathstring_to_path[path_s].length()}"
#         }
#       }
#     }
    @gf_to_paths.each_key { |pos|
      @gf_to_paths[pos].each_key { |gf|
        puts "================"
        puts "POS #{pos} GF #{gf}:"

        @gf_to_paths[pos][gf].values.uniq.sort { |a, b| b <=> a}.each { |frequency|
          sum = 0
          count = 0
          @gf_to_paths[pos][gf].each_pair { |path_s, otherfreq|
            if otherfreq == frequency
              count += 1
              sum += @pathstring_to_path[path_s].length()
            end
          }
          avg_pathlen = sum.to_f / count.to_f

          puts "     Frequency #{frequency}: #{count} path(s)"
          puts "                  #{avg_pathlen} avg. path len"
        }
        puts
      }
    }
    puts
    puts "WORD_TO_GFLIST"
    puts "============================="
    @word_to_gflist.each_pair { |word, gflist|
      print word, " ", gflist.map { |gf, prep, hc| "GF:[#{gf}] PREP:#{prep} HEADCAT:#{hc}" }.join(", "), "\n"
    }
    puts
    puts "============================="
    puts "GF TO EDGELABEL"
    puts "============================="
    @gf_to_edgelabel.each_key { |pos|
      @gf_to_edgelabel[pos].each_pair { |gf, entries|
        puts "POS #{pos} GF #{gf}"
        print_entries(entries, 2)
      }
    }
  end

  #########################################
  # Restricting induced mappings
  # to achieve better mappings
  #########################################

  ####
  # restrict gf_to_edgelabel hashes:
  # exclude all paths that include an Up edge
  #
  # changes @gf_to_edgelabel, not reversible
  def restrict_to_downpaths()
    @gf_to_edgelabel.each_value { |pos_specific|
      pos_specific.each_value { |hash_or_val|
        restrict_pathhash_to_downpaths(hash_or_val)
      }
    }
  end

  ####
  # restrict gf_to_edgelabel hashes:
  # only keep paths up to length n
  #
  # changes @gf_to_edgelabel, not reversible
  def restrict_pathlen(n)  # integer: maximum length to keep
    @gf_to_edgelabel.each_value { |pos_specific|
      pos_specific.each_value { |hash_or_val|
        restrict_pathhash_len(hash_or_val, n)
      }
    }
  end

  ####
  # restrict gf_to_edgelabel hashes:
  # remove GFs that are often incorrect
  def remove_gfs(gf_list)
    gf_list.each { |gf|
      # test output
      @gf_to_edgelabel.each_value { |pos_specific|
        if pos_specific[gf]
#          puts "Remove GFs: removing #{gf}"
        end
        pos_specific.delete(gf)
      }
    }
  end

  #########################################
  # Using stored data
  #########################################


  ###
  # given a SynNode,
  # return all its potential GFs
  # by comparing paths in the parse tree
  # against the GF/path mappings stored in @gf_to_edgelabel
  #
  # returns:
  # hash: SynNode -> tuple [GF(string), preposition(string), frequency(integer)]
  def potential_gfs_of_node(start_node,  # SynNode
                            lemma,       # string: lemma for start_node
                            pos)


    # determine possible GFs of a SynNode:
    #
    # hash: SynNode(some node in this sentence) -> list of tuples [gf label, prep, headcat, hash of steps]
    # initialize with just the entry for the start node
    potential_gfs = Hash.new
    potential_gfs[start_node] = potential_gfs_of_lemma(lemma, pos)
#     $stderr.puts "HIER #{lemma} " + potential_gfs_of_lemma(lemma, pos).map { |gf, prep, hc, hash|
#       "#{gf}:#{prep}:#{hc} "
#     }.join(" ")

    # agenda: list of SynNode objects
    #  that have been considered as potential GFs in the previous step
    #  next: consider their surrounding nodes
    #
    # so, we never assign a GF to the start node
    agenda = [start_node]
    # been_there: list of SynNode objects
    #  that have been considered already and needn't be visited again
    been_there = Hash.new
    been_there[start_node] = true

    # hash: SynNode -> tuple [GF(string), preposition(string), frequency(integer)]
    #      node identified for this sentence for GF,
    #      frequency: frequency with which the path from verb to GF has
    #                 been seen in the FN data (such that we can keep
    #                 the best path and discard others)
    node_to_label_and_freq = Hash.new()

    while not(agenda.empty?)
      prev_node = agenda.shift()

      unless potential_gfs[prev_node]
        # no further GFs to be reached from prev_node:
        # shouldn't be here, but never mind, just ignore
        next
      end

      # surrounding_nodes returns a list of pairs [SynNode, Path object]
      @interpreter.surrounding_nodes(prev_node, true).each { |node, path|
        myprep = @interpreter.preposition(node)
        if myprep
          myprep.downcase!
        end
        h = @interpreter.head_terminal(node)
        if h
          my_headcat = @interpreter.category(h)
        else
          my_headcat = nil
        end

        if been_there[node]
          next
        end

        been_there[node] = true

        unless potential_gfs[node]
          potential_gfs[node] = Array.new
        end

        path.each_step() { |step|
          # each edge from prev_node to node:
          # see whether we can walk this edge to reach some of the GFs
          # still to be reached

          step_s = string_step(step)

          potential_gfs[prev_node].each { |gf, prep, headcat, hash|

            if hash[step_s]
              # yes, there is still a possibility of reaching gf
              # from our current node

              if hash[step_s].kind_of? Integer
                # actually, we have reached gf,
                # and hash[last_edge] is the frequency with which
                # this path has led to this GF in the FN data

                freq = hash[step_s]

                # check whether node has the right preposition
                # and the right head category
                if myprep != prep or
                    my_headcat != headcat
                  # we were supposed to find a preposition
                  # but didn't , or didn't find the right one;
                  # or we got the wrong head category
                  # discard current entry

                elsif not(node_to_label_and_freq[node]) or
                    node_to_label_and_freq[node].last < freq
                  # this node has not been assigned any GF before,
                  # or the old frequency was lower than the current one:
                  # keep the new entry
                  node_to_label_and_freq[node] = [gf, prep, freq]

                else
                  # this node has been assigned a GF before, and the
                  # other frequency was higher:
                  # discard the current entry
                end

              else
                # we have not yet reached gf, but we still might
                # at the next node we meet from here
                potential_gfs[node] << [gf, prep, headcat, hash[step_s]]
              end
            end
          } # each gf/hash pair for prev_node
        } # each edge leading from prev_node to node

        # further explore the parse from this node?
        # only if there are still GFs to be reached from here
        unless potential_gfs[node].empty?
          unless agenda.include? node
            agenda << node
          end
        end
      } # each surrounding node of prev_node
    end # while agenda nonempty

    return node_to_label_and_freq
  end



  ####################################
  ####################################
  private

  #########################################
  # Strings for hashing
  #########################################

  def string_lemmapos(lemma, pos)
    return lemma.to_s + "!" + pos.to_s
  end

  ###
  # make key for gf_to_edgelabel hash
  #
  # step: array of things, the first 3 being strings
  #      direction, edgelabel, nodelabel
  #
  # returns: string, the key
  def string_step(step)
    direction = step[0]
    edgelabel = step[1]
    nodelabel = step[2]

    return "#{direction} #{edgelabel} #{nodelabel}"
  end

  #########################################
  # Storing induced mappings
  #########################################

  ####
  # build up linked hashes that map
  # paths to frequencies
  def enter_path(hash,       # partial result of enter_path
                 chainlinks, # array: string*string*string
                 frequency)  # integer: frequency of this mapping
    # take off first chain link
    key = string_step(chainlinks.shift())

    if chainlinks.empty?
      # that was the last link, actually
      hash[key] = frequency
    else
      # more links available
      unless hash[key]
        hash[key] = Hash.new()
      end

      if hash[key].kind_of? Integer
        # there is a shorter path for the same GF,
        # ending at the point where we are now.
        # which frequency is higher?
        if frequency > hash[key]
          hash[key] = Hash.new()
        else
          return
        end
      end

      enter_path(hash[key], chainlinks, frequency)
    end
  end


  #########################################
  # Test output
  #########################################

  ###
  # test output:
  # print results of enter_path
  def print_entries(hash, num_spaces)
    hash.each_pair { |first_link, rest|
      print " "*num_spaces, first_link

      if rest.kind_of? Integer
        puts "  #{rest}"
      else
        puts
        print_entries(rest, num_spaces + 2)
      end
    }
  end

  #########################################
  # Restricting induced mappings
  # to achieve better mappings
  #########################################

  ###
  # recursive function:
  # if the argument is a hash,
  # kill all entries whose keys describe an Up step in the path,
  # go into recursion for remaining entries
  def restrict_pathhash_to_downpaths(hash_or_val) # path hash or integer freq
    if hash_or_val.kind_of? Integer
      return
    end

    # remove up edges
    hash_or_val.delete_if { |key, val|
      # test output
#      if key =~ /^U/
#        puts "Deleting up path"
#      end
      key =~ /^U/
    }

    hash_or_val.each_value { |next_hash|
      restrict_pathhash_to_downpaths(next_hash)
    }
  end

  ###
  # recursive function:
  # if the argument is a hash and
  # the remaining path length is 0, kill all entries
  # else go into recursion for all entries with reduced path length
  def restrict_pathhash_len(hash_or_val,  # path hash or integer freq
                            n)            # restrict paths from what length?
    if hash_or_val.kind_of? Integer
      return
    end

    if n == 0
      # test output
 #     hash_or_val.keys.each { |k| puts "deleting because of path len: #{k}" }
      hash_or_val.keys.each { |k| hash_or_val.delete(k) }
    else
      hash_or_val.each_value { |next_hash|
        restrict_pathhash_len(next_hash, n-1)
      }
    end
  end

  #########################################
  # Using stored data
  #########################################

  ###
  # given a lemma,
  # look in its list of all GFs that we have ever found for that lemma
  #
  # returns: array of pairs [gf label, point in gf_to_edgelabel hash]
  #   all the labels of GFs of this word,
  #   and for each GF, the matching GF-to-path hash
  def potential_gfs_of_lemma(lemma, pos)

    lemmapos = string_lemmapos(lemma, pos)

    if @word_to_gflist[lemmapos]
      return @word_to_gflist[lemmapos].map { |gf, prep, headcat|
        [gf, prep, headcat, @gf_to_edgelabel[pos][gf]]
      }.select { |gf, prep, headcat, hash|
#         if hash.nil?
#           $stderr.puts "Mapping words to GF lists: no entry for GF >>#{gf}<< for POS #{pos}"
#         end
        not(hash.nil?)
      }
    else
      return []
    end
  end
end

#####################################################################
# class managing subcat frames
#####################################################################


class GfiSubcatFrames

  #########################################
  # Initialization
  #########################################

  ###
  # include_sem: include frame and FE names in
  # subcat frame? if not, the tuple arity stays the same,
  # but frame and FE entries will be nil
  def initialize(include_sem) # boolean
    # hash: word(string) -> array:[frame(string), subcatframe]
    #  with subcatframe an array of tuples [gf, prep, fe, multiplicity]
    @word_to_subcatframes = Hash.new

    # hash: <subcatframe encoded as string> -> frequency
    @subcat_to_freq = Hash.new(0)

    @include_sem = include_sem
  end

  #########################################
  # Storing induced mappings
  #########################################

  ###
  # store a subcat frame in this object.
  # subcat frame given as an array of tuples
  #  [gf, prep, fe]
  def store_subcatframe(scf,   # tuples as described above
                        frame, # frame: string
                        lemma, # lemma: string
                        pos)   # part of speech: string

    lemmapos = string_lemmapos(lemma, pos)
    unless @include_sem
      frame = nil
    end

    unless @word_to_subcatframes[lemmapos]
      @word_to_subcatframes[lemmapos] = Array.new
    end

    # reencode subcat frame:
    # array of tuples [gf, prep, fe_concat, multiplicity]
    #
    # multiplicity is either "one" or "many", depending on
    # the number of times the same gf/prep pair occurred.
    # If the same gf/prep pair occurred with different FEs, they
    # will be concatenated into a space-separated string
    # with a single subcat entry
    count_gfprep = Hash.new(0)
    gfprep_to_fe = Hash.new

    scf.each { |gf, prep, fe|
      count_gfprep[[gf, prep]] += 1
        unless gfprep_to_fe[[gf, prep]]
          gfprep_to_fe[[gf, prep]] = Array.new
        end
        unless gfprep_to_fe[[gf, prep]].include?(fe)
          gfprep_to_fe[[gf, prep]] << fe
        end
    }
    subcatframe = count_gfprep.to_a.map { |gfprep, count|
      gf, prep = gfprep
      if @include_sem
        fe = gfprep_to_fe[[gf, prep]].join(" ")
      else
        fe = nil
      end
      if count == 1
        [gf, prep, fe, "one"]
      else
        [gf, prep, fe, "many"]
      end
    }.sort { |a, b|
      if a[0] != b[0]
        # compare GF
        a[0] <=> b[0]
      else
        # compare prep
        a[1].to_s <=> b[1].to_s
      end
    }

    # store subcat frame
    unless @word_to_subcatframes[lemmapos].include? [frame, subcatframe]
      @word_to_subcatframes[lemmapos] << [frame, subcatframe]
    end

    # count subcat frame
    @subcat_to_freq[string_subcatframe(subcatframe)] += 1
  end

  #########################################
  # Test output
  #########################################

  ###
  def test_output()
    puts "WORD_TO_SUBCATFRAMES"
    @word_to_subcatframes.each_pair { |word, frames_and_mappings|
      puts word
      frames_and_mappings.each { |frame, subcatframe|
        puts "\t#{frame} "+ subcatframe.to_a.map { |gf, prep, fe, freq| "[#{gf}]:#{prep}:#{fe}:#{freq}" }.join(" ")
        puts "\t\tfreq #{@subcat_to_freq[string_subcatframe(subcatframe)]}"
      }
    }
    puts
  end

  #########################################
  # Using stored data
  #########################################

  ###
  def lemma_known(lemma, pos) # string*string
    if @word_to_subcatframes[string_lemmapos(lemma, pos)]
      return true
    else
      return false
    end
  end


  ###
  # given a mapping from nodes to gf/prep pairs,
  # match them against the subcat frames known for the lemma/POS pair.
  #
  # node_to_gf:
  # hash: SynNode -> tuple [GF(string), preposition(string), frequency(integer)]
  #
  # strict: boolean. If true, return only those subcat frames that exactly match
  #   all GFs listed in node_to_gf. If false, also return subcat frames that
  #   match a subset of the GFs mentioned in node_to_gf.
  #
  # returns: list of tuples [frame(string), subcat frame, frequency(integer)],
  # where a subcat frame is an array of tuples
  # [gf (string), prep(string or nil), fe(string), synnodes(array:SynNode)]
  #    and the syn_nodes are sorted by confidence, best first
  def match(start_node, # SynNode
            lemma,      # string
            pos,         # string
            node_to_gf, # hash as described above
            strict)     # boolean: true: strict match. false: subseteq match

    unless lemma_known(lemma, pos)
      return []
    end

#     $stderr.puts "HIER4 GFs found: " + node_to_gf.values.map { |gf, prep, freq|
#       "#{gf}:#{prep}"
#     }.join(" ")
#     $stderr.puts "HIER5 GF possible: (#{@word_to_subcatframes[string_lemmapos(lemma, pos)].length()})"
#     @word_to_subcatframes[string_lemmapos(lemma, pos)].each { |frame, scf|
#       scf.each { |gf, prep, fe, mult|
#         $stderr.print "#{gf}:#{prep} "
#       }
#       $stderr.puts
#     }

    # word_to_subcatframes:
    # hash: lemma(string) -> array:[frame(string), subcatframe]
    #  with subcatframe: array of tuples [gf, prep, fe, multiplicity]
    scf_list = @word_to_subcatframes[string_lemmapos(lemma, pos)].map { |frame, subcatframe|
      [
        frame,
        # returns: array of tuples [gf, prep, fe, syn_nodes]
        match_subcat(subcatframe, node_to_gf, strict),
        @subcat_to_freq[string_subcatframe(subcatframe)]
      ]
    }.select { |frame, subcatframe, frequency| not(subcatframe.nil?) }

    # scf_list may contain duplicates if some GF exists both with multiplicity "many" and
    # muiltiplicity "one", and the "many" has only been filled by one
    #
    # so sort by frequency, then discard duplicates using a "seen" hash
    seen = Hash.new
    return scf_list.sort { |a, b| b.last <=> a.last }.select { |frame, subcatframe, frequency|
      sc_string = string_subcatframe_withnodes(subcatframe)
      if seen[sc_string]
        false
      else
        seen[sc_string] = true
        true
      end
    }
  end

  ###
  # given a subcat frame and a hash mapping each node to a gf/prep pair,
  # check whether the node/gf mapping matches the subcat frame.
  # Match:
  # * for each node/gf mapping, the GF/prep occurs in the subcat frame
  #   (But if there are many nodes for the same GF/prep and
  #    multiplicity is "one", nodes may be discarded.)
  # * each entry in the subcat frame is matched by at least one node,
  #   and multiplicity="many" entries are matched by at least two
  #
  # subcatframe: array of tuples [gf, prep, fe, multiplicity]
  # node_to_gf:
  #   hash: SynNode -> tuple [GF(string), preposition(string), frequency(integer)]
  #
  # returns:
  #  nil on mismatch.
  #  match: copy of the subcat frame, each entry minus multiplicity but plus matching syn nodes
  def match_subcat(subcatframe,  # array of tuples as described above
                   node_to_gf,   # hash as described above
                   strict)       # boolean: strict match, or subseteq match?

    # each node of the node -> gf hash:
    # check whether the GF of the node->gf mapping
    # occurs in the subcat frame
    # if it does, remember it in entry_to_nodes
    # if it does not, regard the match as failed
    entry_to_nodes = Hash.new

    node_to_gf.each_key {|node|
      gf, prep, frequency = node_to_gf[node]
      match_found = false

      subcatframe.each { |other_gf, other_prep, fe, multiplicity|

        if other_gf == gf and other_prep == prep
          # match
          unless entry_to_nodes[[gf, prep]]
            entry_to_nodes[[gf, prep]] = Array.new
          end
          entry_to_nodes[[gf, prep]] << node
          match_found = true
          break
        end
      }
      if strict and not(match_found)
        # this node does not fit into this subcat frame
        # mismatch
        return nil
      end
    } # each node from node_to_gf


    subcatframe.each { |gf, prep, fe, multiplicity|

      # opposite direction:
      # see if all slots of the subcat frame have been matched against at least one SynNode,
      # otherwise discard
      unless entry_to_nodes[[gf, prep]]
        return nil
      end

      # only one node to be returned for this slot:
      # use the one with the highest frequency for its gf->path mapping
      if multiplicity == "one" and entry_to_nodes[[gf, prep]].length() > 1
        # sort nodes by the frequency
        # entries in node_to_gf,
        # then keep only the <multiplicity> first ones
        entry_to_nodes[[gf, prep]] = entry_to_nodes[[gf, prep]].sort { |node1, node2|
          node_to_gf[node2].last <=> node_to_gf[node1].last
        }.slice(0, 1)
      end
    }

    # make extended subcat frame and return it
    return subcatframe.map { |gf, prep, fe, multiplicity|
      # sort "many" nodes by the frequency of their gf->path mapping
      [
        gf, prep, fe,
        entry_to_nodes[[gf, prep]].sort { |node1, node2|
          node_to_gf[node2].last <=> node_to_gf[node1].last
        }
      ]
    }
  end

  ####################################
  ####################################
  private

  #########################################
  # Making strings for hashing
  #########################################

  ###
  def string_lemmapos(lemma, pos)
    return lemma.to_s + "!" + pos.to_s
  end

  ###
  # subcatframe to string
  #
  # subcatframe: array of tuples [gf, prep, fe, multiplicity]
  # sort (to make subcat frames comparable) and
  # turn to string
  def string_subcatframe(subcatframe)

    return subcatframe.map { |gf, prep, fes, count| "#{gf} #{prep} #{count}" }.sort.join(", ")
  end

  # subcatframe to string
  #
  # here: we have a list of SynNodes instead of the multiplicity
  def string_subcatframe_withnodes(subcatframe)
    return subcatframe.map { |gf, prep, fes, nodes| "#{gf} #{prep} " + nodes.map { |n| n.id.to_s }.join(",") }.sort.join(" ")
  end

end

#####################################################################
# main class
#####################################################################

class GfInduce

  #########################################
  # Initialization
  #########################################

  ###
  # initialize everything to an empty hash,
  # preparing for induce_from_sent.
  # If you would like to start with induced GF already in,
  # in order to use apply(), do GfInduce.from_file(filename)
  #
  # include_sem: if true, keep frame name and FE name
  # as part of the subcat frame. if false, don't keep them
  def initialize(interpreter_class, # SynInterpreter class
                 include_sem = false)# boolean

    @interpreter = interpreter_class
    @gf_path_map = GfiGfPathMapping.new(interpreter_class)
    @subcat_frames = GfiSubcatFrames.new(include_sem)
  end

  #########################################
  # Pickling
  #########################################

  ###
  # save this GfInduce object (as a pickle) to the given file
  def to_file(filename) # string
    begin
      file = File.new(filename, "w")
    rescue
      $stderr.puts "GfInduce error: couldn't write to file #{filename}."
      return
    end

    file.puts Marshal.dump(self)
    file.close()
  end

  ###
  # load a GfInduce object from the given file
  # and return it.
  # Returns nil if reading from the file failed.
  def GfInduce.from_file(filename) # string
    begin
      file = File.new(filename)
    rescue
      $stderr.puts "GfInduce error: couldn't read from file #{filename}."
      return nil
    end

    gfi_obj =  Marshal.load(file)
    file.close()
    return gfi_obj
  end

  #########################################
  # Inducing mappings from training data
  #########################################

  ###
  # induce path -> gf mapping from the given SalsaTigerSentence object
  #
  # Assumption: sent contains semantic annotation: FrameNet frames
  # and the FEs of the frames have information on grammatical function (gf)
  # and phrase type (pt) of the phrase that the FE points to
  # as attributes on FeNode objects (which represent <fe> elements in the
  # underlying Salsa/Tiger XML representation)
  def induce_from_sent(sent) # SalsaTigerSentence object

    # induce GFs from each frame of the sentence
    sent.each_frame { |frame|
      unless frame.target
        # frame without a target:
        # nothing I can do
        next
      end

      # main target node, lemma
      maintarget, targetlemma, targetpos = mainnode_and_lemma(frame.target.children())
      if not(maintarget) or not(targetlemma)
        # cannot count this one
        next
      end

      # array of tuples [gfpt, prep, fe]
      subcatframe = Array.new

      # each FE (but not the target itself):
      frame.each_child { |fe|
        if fe.name == "target"
          next
        end

        if not(fe.get_attribute("gf")) and not(fe.get_attribute("pt"))
          # no GF or PT information: nothing to learn here
          next
        end

        gfpt = "#{fe.get_attribute("gf")} #{fe.get_attribute("pt")}"

        # compute path between main target and FE syn nodes,
        # store mapping gfpt -> path in fngf_to_paths
        fe.each_child { |syn_node|

          # determine path,
          path = @interpreter.path_between(maintarget, syn_node, true)

          # store the mapping
          @gf_path_map.store_mapping(gfpt, path, syn_node, targetlemma, targetpos)

          # preposition?
          prep = @interpreter.preposition(syn_node)
          if prep
            prep.downcase!
          end

          # remember combination gfpt/prep/fe
          # as part of the subcat frame
          subcatframe << [gfpt, prep, fe.name()]
        } # each syn node that the FE points to
      } # each FE of the frame

      # store the subcat frame
      @subcat_frames.store_subcatframe(subcatframe, frame.name(), targetlemma, targetpos)
    } # each frame
  end

  ###
  # finish up inducing:
  #  reencode information in a fashion
  #  that makes apply() faster
  def compute_mapping()
    @gf_path_map.finish_inducing()
  end

  #########################################
  # Test output
  #########################################

  ###
  def test_output()
    @gf_path_map.test_output()
    @subcat_frames.test_output()
  end

  #########################################
  # Restricting induced mappings
  # to achieve better mappings
  #########################################

  ####
  # restrict gf -> path mappings:
  # exclude all paths that include an Up edge
  def restrict_to_downpaths()
    @gf_path_map.restrict_to_downpaths()
  end

  ####
  # restrict gf -> path mappings:
  # only keep paths up to length n
  def restrict_pathlen(n)  # integer: maximum length to keep
    @gf_path_map.restrict_pathlen(n)
  end

  ####
  # restrict gf -> path mappings:
  # remove GFs that are often incorrect
  def remove_gfs(gf_list)
    @gf_path_map.remove_gfs(gf_list)
  end

  #########################################
  # Applying mappings to new data
  #########################################



  ###
  # given a list of nodes (idea: they form a MWE together;
  #  may of course be a single node),
  # determine all subcat frames, i.e. all consistent sets of grammatical functions,
  # for the main node among the nodelist.
  # For each subcat frame, potential FN frames and FE labels
  # are returned as well
  #
  # strict: boolean. If true, return only those subcat frames that exactly match
  #   all GFs listed in node_to_gf. If false, also return subcat frames that
  #   match a subset of the GFs mentioned in node_to_gf.
  #
  #
  # returns: list of tuples [frame(string), subcat frame, frequency(integer)],
  # where a subcat frame is an array of tuples
  # [gf (string), prep(string or nil), fe(string), synnodes(array:SynNode)]
  def apply(nodelist, # array:SynNode
            strict = false) # match: strict or subseteq?

    mainnode, lemma, pos = mainnode_and_lemma(nodelist)
    if not(mainnode) or not(lemma)
      return []
    end

    unless @subcat_frames.lemma_known(lemma, pos)
      # nothing known about the lemma
      return []
    end

    # hash: SynNode -> tuple [GF(string), preposition(string), frequency(integer)]
    node_to_gf = @gf_path_map.potential_gfs_of_node(mainnode, lemma, pos)

#     $stderr.puts "HIER m:#{mainnode.to_s} l:#{lemma} p:{pos} "+ nodelist.map { |n| n.to_s}.join(" ")
#     $stderr.puts "HIER2 #{@subcat_frames.lemma_known(lemma, pos)}"
#     $stderr.puts "HIER3 #{node_to_gf.length()}"


    return @subcat_frames.match(mainnode, lemma, pos, node_to_gf, strict)
  end


  #########################################
  #########################################
  private

  #########################################
  # Main node, lemma, POS of given expression
  #########################################

  ###
  # determine main node and its lemma
  #
  # returns: SynNode*string*string, main node, lemma, POS
  def mainnode_and_lemma(nodelist)
    mainnode = @interpreter.main_node_of_expr(nodelist)
    unless mainnode
      return [nil, nil, nil]
    end

    lemma = @interpreter.lemma_backoff(mainnode)
    pos = @interpreter.category(mainnode)

    # verb? then add the voice to the POS
    if (voice = @interpreter.voice(mainnode))
      pos = pos + "-" + voice
    end
    return [mainnode, lemma, pos]
  end

end
