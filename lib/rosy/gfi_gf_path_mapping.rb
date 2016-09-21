module Shalmaneser
  module Rosy
    class GfiGfPathMapping

      #########################################
      # Initialization
      #########################################

      ###
      def initialize(interpreter_class)

        @interpreter = interpreter_class

        # hash: POS(string) -> hash gf(string) -> hash: path_string -> frequency(int)
        @gf_to_paths = {}

        # hash: POS(string)-> hash: gf(string) -> hash: one edge of a path ->
        #  frequency(int) | hash: one edge of a path -> ...
        @gf_to_edgelabel = {}

        # hash: word(string) -> array: [gf, prep, head_category]
        @word_to_gflist = {}

        # hash: path as string(string) -> array of steps
        # where a step is a tuple of stringss [{U, D}, edgelabel, nodelabel}
        @pathstring_to_path = {}
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
          @pathstring_to_path[path_s] = []
          path.each_step { |direction, edgelabel, nodelabel, node|
            @pathstring_to_path[path_s] << [direction, edgelabel, nodelabel]
          }
        end

        # store the mapping in the
        # gf -> path hash
        unless @gf_to_paths[pos]
          @gf_to_paths[pos] = {}
        end
        unless @gf_to_paths[pos][gf]
          @gf_to_paths[pos][gf] = Hash.new(0)
        end
        @gf_to_paths[pos][gf][path_s] = @gf_to_paths[pos][gf][path_s] + 1


        # remember this gf/pt tuple as possible GF of the current lemma
        unless @word_to_gflist[lemmapos]
          @word_to_gflist[lemmapos] = []
        end
        unless @word_to_gflist[lemmapos].include? [gf, prep, headcat]
          @word_to_gflist[lemmapos] << [gf, prep, headcat]
        end
      end

      ###
      # finish up inducing:
      #  reencode information in a fashion
      #  that makes apply() faster
      def finish_inducing
        # make sure gf_to_edgelabel is empty at the start
        @gf_to_edgelabel.clear

        @gf_to_paths.each_pair { |pos, gf_to_paths_to_freq|
          unless @gf_to_edgelabel[pos]
            @gf_to_edgelabel[pos] = {}
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
                  @gf_to_edgelabel[pos][gf] = {}
                end

                enter_path(@gf_to_edgelabel[pos][gf], steps.clone, freq)
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
      def test_output
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
        #           puts "#{path_s} freq:#{freq} len:#{@pathstring_to_path[path_s].length}"
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
                  sum += @pathstring_to_path[path_s].length
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
      def restrict_to_downpaths
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
        potential_gfs = {}
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
        been_there = {}
        been_there[start_node] = true

        # hash: SynNode -> tuple [GF(string), preposition(string), frequency(integer)]
        #      node identified for this sentence for GF,
        #      frequency: frequency with which the path from verb to GF has
        #                 been seen in the FN data (such that we can keep
        #                 the best path and discard others)
        node_to_label_and_freq = {}

        while not(agenda.empty?)
          prev_node = agenda.shift

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
              potential_gfs[node] = []
            end

            path.each_step { |step|
              # each edge from prev_node to node:
              # see whether we can walk this edge to reach some of the GFs
              # still to be reached

              step_s = string_step(step)

              potential_gfs[prev_node].each { |gf, prep, headcat, hash|

                if hash[step_s]
                  # yes, there is still a possibility of reaching gf
                  # from our current node

                  if hash[step_s].is_a? Integer
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
        key = string_step(chainlinks.shift)

        if chainlinks.empty?
          # that was the last link, actually
          hash[key] = frequency
        else
          # more links available
          unless hash[key]
            hash[key] = {}
          end

          if hash[key].is_a? Integer
            # there is a shorter path for the same GF,
            # ending at the point where we are now.
            # which frequency is higher?
            if frequency > hash[key]
              hash[key] = {}
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

          if rest.is_a? Integer
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
        if hash_or_val.is_a? Integer
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
        if hash_or_val.is_a? Integer
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
  end
end
