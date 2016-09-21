require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # is the current node a maximal projection?
    # heuristic: is my category the same as my parent's?
    class IsMaxProj < SingleFeatureExtractor
      IsMaxProj.announce_me

      def IsMaxProj.feature_name
        return "ismaxproj"
      end
      def IsMaxProj.sql_type
        return "TINYINT"
      end
      def IsMaxProj.feature_type
        return "syn"
      end

      #####
      private

      def compute_feature_instanceOK
        unless @@node.parent
          return 1
        end
        my_cat = @@interpreter_class.category(@@node)
        parent_cat = @@interpreter_class.category(@@node.parent)
        if my_cat == parent_cat
          return 0
        else
          return 1
        end
      end
    end
  end
end
