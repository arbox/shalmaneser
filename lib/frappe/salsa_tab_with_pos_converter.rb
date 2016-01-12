require 'logging'

require 'salsa_tiger_xml/salsa_tiger_xml_helper'
require 'frappe/file_parser'
require 'external_systems'

module Shalmaneser
  module Frappe
    class SalsaTabWithPOSConverter
      def initialize(exp)
        @exp = exp
        # suffixes for different types of output files
        @file_suffixes = {"lemma" => ".lemma", "pos" => ".pos", "tab" => ".tab", "stxml" => ".xml"}
      end
      ###############
      # transform_salsatab
      #
      # transformation for Tab format files:
      #
      # - parse
      # - Transform parser output to SalsaTigerXML
      #   If no parsing, make flat syntactic structure.
      # @param [String] input_dir Input directory.
      # @param [String] parse_dir Output directory for parses.
      # @param [String] output_dir Global output directory.
      def transform_salsatab_dir(input_dir, parse_dir, output_dir)
        ##
        # (Parse and) transform to SalsaTigerXML
        # get interpretation class for this
        # parser/lemmatizer/POS tagger combination
        interpreter_class = ExternalSystems.get_interpreter_according_to_exp(@exp)

        unless interpreter_class
          raise "Shouldn't be here"
        end

        parse_obj = FileParser.new(@exp, @file_suffixes, parse_dir, "tab_dir" => input_dir)

        parse_obj.each_parsed_file do |parsed_file_obj|
          outfilename = output_dir + parsed_file_obj.filename + ".xml"
          LOGGER.debug "Writing #{outfilename}."

          begin
            outfile = File.new(outfilename, "w")
          rescue
            raise "Cannot write to SalsaTigerXML output file #{outfilename}"
          end

          outfile.puts STXML::SalsaTigerXMLHelper.get_header
          # work with triples
          # SalsaTigerSentence, FNTabSentence,
          # hash: tab sentence index(integer) -> array:SynNode
          parsed_file_obj.each_sentence do |st_sent, tabformat_sent, mapping|
            # parsed: add headwords using parse tree
            if @exp.get("do_parse")
              add_head_attributes(st_sent, interpreter_class)
            end

            # add lemmas, if they are there. If they are not, don't print out a warning.
            if @exp.get("do_lemmatize")
              add_lemmas_from_tab(st_sent, tabformat_sent, mapping)
            end

            # add semantics
            # we can use the method in SalsaTigerXMLHelper
            # that reads semantic information from the tab file
            # and combines all targets of a sentence into one frame
            add_semantics_from_tab(st_sent, tabformat_sent, mapping, interpreter_class, @exp)

            # remove pseudo-frames from FrameNet data
            remove_deprecated_frames(st_sent, @exp)

            # handle multiword targets
            handle_multiword_targets(st_sent, interpreter_class, @exp.get("language"))

            # handle Unknown frame names
            handle_unknown_framenames(st_sent, interpreter_class)

            outfile.puts st_sent.get
          end
          outfile.puts STXML::SalsaTigerXMLHelper.get_footer
        end
      end

      # add lemma information to each terminal in a given SalsaTigerSentence object
      # @param [SalsaTigerSentence] st_sent
      # @param [FNTabFormatSentence] tab_sent
      # @param [Hash] mapping hash: tab lineno -> array:SynNode
      def add_lemmas_from_tab(st_sent, tab_sent, mapping)
        if tab_sent.nil?
          # tab sentence not found
          return
        end

        # produce list with word, lemma pairs
        lemmat = []
        tab_sent.each_line_parsed {|line|
          word = line.get("word")
          lemma = line.get("lemma")
          lemmat << [word, lemma]
        }

        # match with st_sent terminal list and add lemma attributes
        # KE Jan 07: if word mismatch,
        # set to Lemmatizer file version,
        # but count mismatches
        word_mismatches = []

        st_sent.each_terminal_sorted { |t|
          matching_lineno = (0...lemmat.length).to_a.detect { |tab_lineno|
            mapping[tab_lineno].include? t
          }
          unless matching_lineno
            next
          end
          word, lemma = lemmat[matching_lineno]

          # transform characters to XML-friendly form
          # for comparison with st_word, which is also escaped
          word = STXML::SalsaTigerXMLHelper.escape(word)
          st_word = t.word
          if word != st_word && word != STXML::SalsaTigerXMLHelper.escape(st_word)
            # true mismatch.
            # use the Lemmatizer version of the word, remember the mismatch
            word_mismatches << [st_word, word]
            t.set_attribute("word", word)
          end

          if lemma
            # we actually do have lemma information
            lemmatised_head = STXML::SalsaTigerXMLHelper.escape(lemma)
            t.set_attribute("lemma",lemmatised_head)
          end
        } # each terminal

        # did we have mismatches? then report them
        unless word_mismatches.empty?
          $stderr.puts "Warning: Word mismatches found between Lemmatizer file and SalsaTigerXML file generalted from parser output."
          $stderr.puts "(May be due to failed reencoding of special character in the parser output.)"
          $stderr.puts "I am using the Lemmatizer version by default."
          $stderr.puts "Version used:"
          $stderr.print "\t"
          st_sent.each_terminal_sorted { |t| $stderr.print ">>#{t}<<" }
          $stderr.puts
          $stderr.print "SalsaTigerXML file had: "
          $stderr.print word_mismatches.map { |st_word, tab_word|
            "#{st_word} instead of #{tab_word}"
          }.join(", ")
          $stderr.puts
        end
      end


      ###
      # add semantics from tab:
      #
      # add information about semantics from a FN tab sentence
      # to a SalsaTigerSentence object:
      # - frames (one frame per sentence)
      # - roles
      # - FrameNet grammatical functions
      # - FrameNet POS of target
      def add_semantics_from_tab(st_sent,  # SalsaTigerSentence object
                                              tab_sent, # FNTabFormatSentence object
                                              mapping,  # hash: tab lineno -> array:SynNode
                                              interpreter_class, # SynInterpreter class
                                              exp)      # FrprepConfigData

        if tab_sent.nil?
          # tab sentence not found
          return
        end

        # iterate through frames in the tabsent
        frame_index = 0
        tab_sent.each_frame { |tab_frame_obj|
          frame_name = tab_frame_obj.get_frame # string

          if frame_name.nil? or frame_name =~ /^-*$/
            # weird: a frame without a frame
            $stderr.puts "Warning: frame entry without a frame in tab sentence #{st_sent.id}."
            $stderr.puts "Skipping"
            next
          end

          frame_node = st_sent.add_frame(frame_name, tab_sent.get_sent_id + "_f#{frame_index}")
          frame_index += 1

          # target
          target_nodes = []
          tab_frame_obj.get_target_indices.each {|terminal_id|
            if mapping[terminal_id]
              target_nodes.concat mapping[terminal_id]
            end
          }

          # let the interpreter class decide on how to determine the maximum constituents
          target_maxnodes = interpreter_class.max_constituents(target_nodes, st_sent)
          if target_maxnodes.empty?
            # HIEr
            STDERR.puts  "Warning: no target in frame entry, sentence #{st_sent.id}."
            $stderr.puts "frame is #{frame_name}, frame no #{frame_index}"
            $stderr.puts "Skipping."
            $stderr.puts "target indices: " + tab_frame_obj.get_target_indices.join(", ")
            #tab_sent.each_line { |line|
            #  $stderr.puts line
            #  $stderr.puts "--"
            #}
            next
          end
          frame_node.add_fe("target",target_maxnodes)

          # set features on target: target lemma, target POS
          target_lemma = tab_frame_obj.get_target
          target_pos = nil
          if target_lemma
            if exp.get("origin") == "FrameNet"
              # FrameNet data: here the lemma in the tab file has the form
              # <lemma>.<POS>
              # separate the two
              if target_lemma =~ /^(.*)\.(.*)$/
                target_lemma = $1
                target_pos = $2
              end
            end
            frame_node.target.set_attribute("lemma", target_lemma)
            if target_pos
              frame_node.target.set_attribute("pos", target_pos)
            end
          end

          # roles, GF, PT
          # synnode_markable_label:
          #   hash "role" | "gf" | "pt" -> SynNode -> array: label(string)
          layer_synnode_label = {}
          ["gf", "pt", "role"].each {|layer|
            termids2labels = tab_frame_obj.markables(layer)

            unless layer_synnode_label[layer]
              layer_synnode_label[layer] = {}
            end

            termids2labels.each {|terminal_indices, label|
              terminal_indices.each { |t_i|

                if (nodes = mapping[t_i])

                  nodes.each { |node|
                    unless layer_synnode_label[layer][node]
                      layer_synnode_label[layer][node] = []
                    end

                    layer_synnode_label[layer][node] << label
                  } # each node that t_i maps to
                end # if t_i maps to anything

              } # each terminal index
            } # each mapping terminal indices -> label
          } # each layer

          # 'stuff' (Support and other things)
          layer_synnode_label["stuff"] = {}
          tab_frame_obj.each_line_parsed { |line_obj|
            if (label = line_obj.get("stuff")) != "-"
              if (nodes = mapping[line_obj.get("lineno")])
                nodes.each { |node|
                  unless layer_synnode_label["stuff"][node]
                    layer_synnode_label["stuff"][node] = []
                  end
                  layer_synnode_label["stuff"][node] << label
                }
              end
            end
          }

          # reencode:
          #  hash role_label(string) -> array of tuples [synnodes, gflabels, ptlabels]
          #   synnodes: array:SynNode.  gflabels, ptlabels: array:String
          #
          # note that in this step, any gf or pt labels that have been
          # assigned to a SynNode that has not also been assigned a role
          # will be lost
          role2nodes_labels = {}
          layer_synnode_label["role"].each_pair { |synnode, labels|
            labels.each { | rolelabel|
              unless role2nodes_labels[rolelabel]
                role2nodes_labels[rolelabel] = []
              end

              role2nodes_labels[rolelabel] << [
                synnode,
                layer_synnode_label["gf"][synnode],
                layer_synnode_label["pt"][synnode]
              ]
            } # each role label
          } # each pair SynNode/role labels

          # reencode "stuff", but only the support cases
          role2nodes_labels["Support"] = []

          layer_synnode_label["stuff"].each_pair { |synnode, labels|
            labels.each { |stufflabel|
              if stufflabel =~ /Supp/
                # some sort of support
                role2nodes_labels["Support"] << [synnode, nil, nil]
              end
            }
          }

          ##
          # each role label:
          # make FeNode for the current frame
          role2nodes_labels.each_pair { |rolelabel, node_gf_pt|

            # get list of syn nodes, GF and PT labels for this role
            # shortcut for GF and PT labels: take any labels that have
            # been assigned for _some_ Synnode of this role
            synnodes = node_gf_pt.map { |ngp| ngp[0] }
            gflabels = node_gf_pt.map { |ngp| ngp[1] }.compact.flatten.uniq
            ptlabels = node_gf_pt.map { |ngp| ngp[2] }.compact.flatten.uniq


            # let the interpreter class decide on how to
            # determine the maximum constituents
            maxnodes = interpreter_class.max_constituents(synnodes, st_sent)

            fe_node = st_sent.add_fe(frame_node, rolelabel, maxnodes)
            unless gflabels.empty?
              fe_node.set_attribute("gf", gflabels.join(","))
            end
            unless ptlabels.empty?
              fe_node.set_attribute("pt", ptlabels.join(","))
            end
          } # each role label
        } # each frame
      end


      ######
      # handle multiword targets:
      # if you find a verb with a separate prefix,
      # change the verb's lemma information accordingly
      # and add an attribute "other_words" to the verb node
      # pointing to the other node
      #
      # In general, it will be assumed that "other_words" contains
      # a list of node IDs for other nodes belonging to the same
      # group, node IDs separated by spaces, and that
      # each node of a group has the "other_words" attribute.
      #
      def handle_multiword_targets(sent,  # SalsaTigerSentence object
                                                interpreter, # SynInterpreter object
                                                language) # string: en, de
        ##
        # only retain the interesting words of the sentence:
        # content words and prepositions
        if sent.nil?
          return
        end

        nodes = sent.terminals.select { |node|
          [
            "adj", "adv", "card", "noun", "part", "prep", "verb"
          ].include? interpreter.category(node)
        }

        ##
        # group:
        # group verbs with their separate particles
        # (at a later point, other types of grouping can be inserted here)
        groups = group_words(nodes, interpreter)

        ##
        # record grouping information as attributes on the terminals.
        groups.each { |descr, group_of_nodes|
          case descr
          when "none"
          # no grouping
          when "part"
            # separate particle belonging to a verb

            # group_of_nodes is a pair [verb, particle]
            verb, particle = group_of_nodes

            verb.set_attribute("other_words", particle.id)
            particle.set_attribute("other_words", verb.id)

            if verb.get_attribute("lemma") and particle.get_attribute("lemma")
              case language
              when "de"
                # German: prepend SVP to get the real lemma of the verb
                verb.set_attribute("lemma",
                                   particle.get_attribute("lemma") +
                                   verb.get_attribute("lemma"))
              when "en"
                # English: append particle as separate word after the lemma of the verb
                verb.set_attribute("lemma",
                                   verb.get_attribute("lemma") + " " +
                                   particle.get_attribute("lemma"))
              else
                # default
                verb.set_attribute("lemma",
                                   verb.get_attribute("lemma") + " " +
                                   particle.get_attribute("lemma"))
              end
            end

          else
            raise "Shouldn't be here: unexpected description #{descr}"
          end
        }
      end

      ########################
      # group_words
      #
      # auxiliary of transform_multiword targets
      #
      # Group terminals:
      # At the moment, just find separate prefixes and particles
      # for verbs
      #
      # returns: list of pairs [descr, nodes]
      # descr: string, "none" (no group), "part" (separate verb particle)
      # nodes: array:SynNode
      def group_words(nodes,    # array: SynNode
                                   interpreter) # SynInterpreter object

        retv = [] # array of groups, array:array:SynNode
        done = [] # remember nodes already covered

        nodes.each { |terminal_node|
          if done.include? terminal_node
            # we have already included this node in one of the groups
            next
          end

          if (svp = interpreter.particle_of_verb(terminal_node, nodes))
            retv << ["part", [terminal_node, svp]]
            done << terminal_node
            done << svp
          else
            retv << ["none", [terminal_node]]
            done << terminal_node
          end

        }

        return retv
      end

      ######
      # handle unknown framenames
      #
      # For all frames with names matching Unknown\d+,
      # rename them to <lemma>_Unknown\d+
      def handle_unknown_framenames(sent,     # SalsaTigerSentence
                                                 interpreter) # SynInterpreter class
        if sent.nil?
          return
        end

        sent.each_frame { |frame|
          if frame.name =~ /^Unknown/
            if frame.target
              maintarget = interpreter.main_node_of_expr(frame.target.children, "no_mwe")
            else
              maintarget = nil
            end
            unless maintarget
              $stderr.puts "Warning: Unknown frame, and I could not determine the target lemma: Frame #{frame.id}"
              $stderr.puts "Cannot repair frame name, leaving it as is."
              return
            end

            # get lemma, if it exists, otherwise get word
            # also, if the lemmatizer has returned a disjunction of lemmas,
            # get the first disjunct
            lemma = interpreter.lemma_backoff(maintarget)
            if lemma
              # we have a lemma
              frame.set_name(lemma + "_" + frame.name)
            else
              # the main target word has no lemma attribute,
              # and somehow I couldn't even get the target word
              $stderr.puts "Warning: Salsa 'Unknown' frame."
              $stderr.puts "Trying to make its lemma-specificity explicit, but"
              $stderr.puts "I could not determine the target lemma nor the target word: frame #{frame.id}"
              $stderr.puts "Leaving 'Unknown' as it is."
            end
          end
        }
      end


      ####################
      # add head attributes to each nonterminal in each
      # SalsaTigerXML file in a directory
      # @param [SalsaTigerSentence] st_sent
      # @param [SynInterpreter] interpreter
      def add_head_attributes(st_sent, interpreter)
        st_sent.each_nonterminal do |nt_node|
          head_term = interpreter.head_terminal(nt_node)
          if head_term && head_term.word
            nt_node.set_attribute("head", head_term.word)
          else
            nt_node.set_attribute("head", "--")
          end
        end # each nonterminal
      end

      ###################
      # given a SalsaTigerSentence,
      # look for FrameNet frames that are
      # test frames, and remove them
      # @param [SalsaTigerSentence] sent
      # @param [FrprepConfigData] exp
      def remove_deprecated_frames(sent, exp)
        unless exp.get("origin") == "FrameNet"
          return
        end

        sent.frames.each do |frame_obj|
          if frame_obj.name == "Boulder" || frame_obj.name =~ /^Test/
            sent.remove_frame(frame_obj)
          end
        end
      end
    end
  end
end
