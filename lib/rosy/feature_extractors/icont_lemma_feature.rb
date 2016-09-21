require 'rosy/feature_extractor'

module Shalmaneser
  module Rosy

    ################
    # informative content word (see AbstractSynFeature): lemma and POS
    class IcontLemmaFeature < FeatureExtractor
      IcontLemmaFeature.announce_me

      def IcontLemmaFeature.designator
        return "icont_word"
      end
      def IcontLemmaFeature.feature_names
        return ["icont_lemma", "icont_pos"]
      end
      def IcontLemmaFeature.sql_type
        return "VARCHAR(20)"
      end
      def IcontLemmaFeature.feature_type
        return "sem"
      end

      #####
      private

      def compute_features_instanceOK
        icont_node = @@interpreter_class.informative_content_node(@@node)
        if icont_node
          return [FeatureExtractor.headlemma(icont_node), FeatureExtractor.headpos(icont_node)]
        else
          return [nil, nil]
        end
      end
    end
  end
end
