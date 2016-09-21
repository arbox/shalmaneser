require 'rosy/feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # right sibling of the current node
    class RightSiblingFeature < FeatureExtractor
      RightSiblingFeature.announce_me

      def RightSiblingFeature.designator
        return "rightsib"
      end
      def RightSiblingFeature.feature_names
        return ["rightsib_pt", "rightsib_lemma"]
      end
      def RightSiblingFeature.sql_type
        return "VARCHAR(20)"
      end
      def RightSiblingFeature.feature_type
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

        node_ix = terminal_index(@@node_rightmost_terminal)
        unless node_ix
          return [nil, nil]
        end

        rightsib_ix = nil
        rightsib = nil
        @@node.parent.children.each { |sibling|
          sib_ix = terminal_index(@@interpreter_class.leftmost_terminal(sibling))
          unless sib_ix
            next
          end

          if sib_ix > node_ix and
            (rightsib.nil? or sib_ix < rightsib_ix)

            rightsib = sibling
            rightsib_ix = sib_ix
          end
        }

        if rightsib
          return [
            @@interpreter_class.simplified_pt(rightsib),
            @@interpreter_class.lemma_backoff(rightsib),
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
