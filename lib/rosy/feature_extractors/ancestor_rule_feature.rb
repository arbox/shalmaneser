require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ##################
    # ancestor rule: grammar rule
    # expanding lowest common ancestor of current node and target
    class AncestorRuleFeature < SingleFeatureExtractor
      AncestorRuleFeature.announce_me

      def AncestorRuleFeature.feature_name
        return "ancestor_rule"
      end
      def AncestorRuleFeature.sql_type
        return "VARCHAR(50)"
      end
      def AncestorRuleFeature.feature_type
        return "syn"
      end

      ################
      private

      def compute_feature_instanceOK
        if @@paths[@@node.id].nil?
          return nil
        end

        lca = @@paths[@@node.id].lca
        unless lca
          return nil
        end

        return @@interpreter_class.simplified_pt(lca).to_s + " -> " +
          lca.children.map { |c| @@interpreter_class.simplified_pt(c).to_s }.join(" ")
      end
    end
  end
end
