requie 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # distance between head word of constituent and target (in words)
    class WordDistanceFeature < SingleFeatureExtractor
      WordDistanceFeature.announce_me

      def WordDistanceFeature.feature_name
        return "worddistance"
      end
      def WordDistanceFeature.sql_type
        return "TINYINT"
      end
      def WordDistanceFeature.feature_type
        return "syn"
      end

      #####
      private

      def compute_feature_instanceOK

        head_term = @@interpreter_class.head_terminal(@@node)
        targ_term = @@interpreter_class.head_terminal(@@target)
        if head_term.nil? or targ_term.nil?
          return nil
        end
        h_id = @@terminals_ordered[head_term]
        t_id = @@terminals_ordered[targ_term]
        if h_id.nil? or t_id.nil?
          return nil
        else
          return (h_id - t_id).abs
        end
      end
    end
  end
end
