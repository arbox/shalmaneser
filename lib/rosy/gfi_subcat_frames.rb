module Shalmaneser
  module Rosy
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
        @word_to_subcatframes = {}

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
          @word_to_subcatframes[lemmapos] = []
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
        gfprep_to_fe = {}

        scf.each { |gf, prep, fe|
          count_gfprep[[gf, prep]] += 1
          unless gfprep_to_fe[[gf, prep]]
            gfprep_to_fe[[gf, prep]] = []
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
      def test_output
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
        #     $stderr.puts "HIER5 GF possible: (#{@word_to_subcatframes[string_lemmapos(lemma, pos)].length})"
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
        seen = {}
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
        entry_to_nodes = {}

        node_to_gf.each_key {|node|
          gf, prep, frequency = node_to_gf[node]
          match_found = false

          subcatframe.each { |other_gf, other_prep, fe, multiplicity|

            if other_gf == gf and other_prep == prep
              # match
              unless entry_to_nodes[[gf, prep]]
                entry_to_nodes[[gf, prep]] = []
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
          if multiplicity == "one" and entry_to_nodes[[gf, prep]].length > 1
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
  end
end
