require_relative 'abstract_feature_extractor'

module Shalmaneser
  module Rosy
    ################################
    # base class for all following feature extractors
    ####
    # ke & sp
    # adapted to new feature extractor class,
    # Collins and Tiger features combined:
    # KE November 2005
    #
    # Feature Extractors for Rosy
    #
    # Contract: each feature extractor inherits from the FeatureExtractor class
    #
    # Feature extractors return nil if no feature value could be
    # returned
    class FeatureExtractor < AbstractFeatureExtractor
      @@instance_ok = nil  # Boolean: set_node(), set_sent() successful?
      @@split_nones = nil  # Boolean: split NONE value for gold feature?

      @@target = nil       # SynNode: main target node
      @@target_pos = nil   # string: part of speech of main target
      @@target_voice = nil # string: "active", "passive", or nil
      @@terminals_ordered = nil # Hash: sentence terminals, mapped onto their word indices (starting with 1)
      @@target_gfs = nil   # Array of pairs [rel, node]: grammatical functions of the target

      @@paths = nil        # Hash: node ID -> path object, path from main target node to the node with that ID
      @@relpos = nil       # string: position of instance relative to target
      @@node_leftmost_terminal = nil   # SynNode objects: first and last terminal
      @@node_rightmost_terminal = nil  # in the yield of @@node

      @@governing_verb = nil # SynNode object: closest governing verb of @@target
      @@gv_paths = nil       # Hash: node ID -> path object, path from main target node to the node with that ID

      ###
      # returns a string: "phase 1" or "phase 2",
      # depending on whether the feature is computed
      # directly from the SalsaTigerSentence and the SynNode objects
      # or whether it is computed from the phase 1 features
      # computed for the training set
      #
      # Here: all features in this packages are phase 1
      def self.phase
        return "phase 1"
      end

      ###
      # returns an array of strings, providing information about
      # the feature extractor
      def self.info
        return super().concat(["rosy"])
      end

      ###
      # set sentence, set node, set general settings: this is done prior to
      # feature computation using compute_feature_value()
      # such that computations that stay the same for
      # several features can be done in advance
      def self.set(var_hash) # hash. possible entries: split_nones=> true/false

        @@split_nones = var_hash["split_nones"]

        return true
      end

      ###
      def self.set_sentence(sent,  # SalsaTigerSentence object
					    frame) # FrameNode object
        super(sent, frame)

        root = @@sent.syn_roots.first
        word_index_counter = 1
        @@terminals_ordered = {}
        root.yield_nodes_ordered.each {|yield_node|
          @@terminals_ordered[yield_node] = word_index_counter
          word_index_counter += 1
        }

        # @@target: main target node (SynNode)
        # WARNING: at this moment, we are
        # not considering true multiword targets.
        # Remove the "no_mwe" parameter in determine_main_target
        # to change this
        unless frame.target
          @@target = nil
          return false
        end
        @@target = @@interpreter_class.main_node_of_expr(frame.target.children, "no_mwe")

        unless @@target
          return false
        end

        # @@target_pos: string, target POS
        @@target_pos = @@interpreter_class.category(@@target)

        # @@target_voice:
        # for verb targets, string, active or passive
        # else nil
        @@target_voice = @@interpreter_class.voice(@@target)
        @@target_gfs = @@interpreter_class.gfs(@@target, @@sent)

        # paths from target to all other nodes in the graph
        @@paths = self.all_paths_from(@@target)

        # governing verb of target.
        # If something goes wrong, this will remain unset
        @@gv_paths = {}
        if (targetlemma = self.headlemma(@@target))
          # determine governing verb
          parent = @@target
          while (parent = parent.parent)
            parentlemma = self.headlemma(parent)

            if @@interpreter_class.category(parent) == "verb" and
               parentlemma != targetlemma
              # success: found the governing verb of the target

              @@governing_verb = @@interpreter_class.head_terminal(parent)
              # paths from governing verb of target to all other nodes in the graph
              if @@governing_verb
                @@gv_paths = self.all_paths_from(@@governing_verb)
              end

              break
            end
          end
        end


        # paths: when printing, leave off the phrase type of the end node
        @@paths.each_value { |p| p.set_cutoff_last_pt_on_printing(true) }
        @@gv_paths.each_value { |p| p.set_cutoff_last_pt_on_printing(true) }

        return true
      end

      ###
      # node: SynNode of the sentence set in set_sentence
      def self.set_node(node)
        super(node)

        @@instance_ok = true

        unless @@target
          # no target, nothing I can compute here
          @@instance_ok = false
          return false
        end

        #    # path between target and current instance node
        #    @@path = @@interpreter_class.path_between(@@target, @@node)
        #    @@path.set_cutoff_last_pt_on_printing(true) # when printing path, cut off last node label


        # position of instance node relative to main target node
        @@relpos = @@interpreter_class.relative_position(@@node, @@target)
        # leftmost, rightmost terminal in the yield of @@node
        @@node_leftmost_terminal = @@interpreter_class.leftmost_terminal(@@node)
        @@node_rightmost_terminal = @@interpreter_class.rightmost_terminal(@@node)

        return true
      end

      ###
      # compute_feature_value: first check if instance is OK
      #
      # returns: list of features
      def compute_features
        unless @@instance_ok
          return nil
        end

        return make_features_safe_for_sql(compute_features_instanceOK)
      end

      ############
      protected


      # returns: list of features
      def compute_features_instanceOK
        raise "Overwrite me"
      end

      ###
      # in computed features:
      # replace "," by COMMA in order not to confuse SQL
      def make_features_safe_for_sql(feature_list)
        return feature_list.map { |feature|
          if feature.is_a? String
            feature.gsub(/,/, "COMMA").gsub(/\\/, "BACK")
          else
            feature
          end
        }
      end


      ###
      # lemma of the head terminal of SynNode n
      def self.headlemma(n) # SynNode
        unless n
          return nil
        end

        h = @@interpreter_class.head_terminal(n)
        if h
          return @@interpreter_class.lemma_backoff(h)
        else
          return nil
        end
      end

      ###
      # part of speech of the head terminal of SynNode n
      def self.headpos(n) # SynNode
        unless n
          return nil
        end

        h = @@interpreter_class.head_terminal(n)
        if h
          return h.part_of_speech
        else
          return nil
        end
      end

      ###
      # Given a SynNode n, recursively determine
      # the paths from n to all other reachable nodes,
      # skipping nodes that already have a path
      # listed in the given hash mapping node IDs to paths.
      # Paths are given as Path objects (see AbstractSynInterface).
      # It is assumed that the graph of n is a tree, which
      # is searched depth-first, first the children, then the parent of n.
      def self.all_paths_from(n,           # SynNode
                                              hash = nil)  # Hash: nodeID(string) => Path object
        # initial step of all: no hash existing yet
        if hash.nil?
          hash = {}
          hash[n.id] = ::Shalmaneser::Frappe::Path.new(n)
        end

        # invariant at this point: n must be listed in hash
        unless hash[n.id]
          raise "Shouldn't be here"
        end

        # for each child c of n: compute its path from the path of n,
        # and explore paths below c
        n.each_child_with_edgelabel { |label, c|
          if hash[c.id].nil?
            hash[c.id] = hash[n.id].deep_clone.add_last_step("D",
                                                             label,
                                                             @@interpreter_class.simplified_pt(c),
                                                             c)
            self.all_paths_from(c, hash)
          end
        }

        # compute the path from n's parent p from the path of n,
        # and explore paths beyond p
        if (p = n.parent) and hash[p.id].nil?
          # node has a parent, and it is not listed in the path hash
          # make a new path for parent: n's path, plus one up-step
          hash[p.id] = hash[n.id].deep_clone.add_last_step("U",
                                                           n.parent_label,
                                                           @@interpreter_class.simplified_pt(p),
                                                           p)
          self.all_paths_from(p, hash)
        end

        hash
      end
    end
  end
end
