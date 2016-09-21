require 'rosy/feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # left sibling of the current node
    class LeftSiblingFeature < FeatureExtractor
      LeftSiblingFeature.announce_me

      def LeftSiblingFeature.designator
        return "leftsib"
      end

      def LeftSiblingFeature.feature_names
        return ["leftsib_pt", "leftsib_lemma"]
      end

      def LeftSiblingFeature.sql_type
        return "VARCHAR(20)"
      end

      def LeftSiblingFeature.feature_type
        return "sem"
      end

      #####
      private

      def compute_features_instanceOK
        # leftsib, rightsib (node)
        # siblings with max lastword/firstword among those with lastword/firstword index
        # smaller/greater than firstword/lastword index of self
        if @@node.parent.nil?
          return [nil, nil]
        end

        node_ix = terminal_index(@@node_leftmost_terminal)
        unless node_ix
          return [nil, nil]
        end

        leftsib_ix = nil
        leftsib = nil
        @@node.parent.children.each { |sibling|
          sib_ix = terminal_index(@@interpreter_class.rightmost_terminal(sibling))
          unless sib_ix
            next
          end

          if sib_ix < node_ix and
            (leftsib.nil? or leftsib_ix < sib_ix)

            leftsib = sibling
            leftsib_ix = sib_ix
          end
        }

        if leftsib
          return [
            @@interpreter_class.simplified_pt(leftsib),
            @@interpreter_class.lemma_backoff(leftsib),
          ]
        else
          return [nil, nil]
        end
      end

      ###
      # returns: index(integer) of node in list of terminals of this sentence;
      # nil if node is nil or does not occur in the list
      def terminal_index(node) # SynNode, terminal
        unless node
          return nil
        end

        return @@terminals_ordered[node] # word index (or nil)
      end
    end
  end
end
