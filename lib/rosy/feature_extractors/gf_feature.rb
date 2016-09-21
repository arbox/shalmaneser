require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # grammatical function that this instance node fills for the target
    class GFFeature < SingleFeatureExtractor
      GFFeature.announce_me

      def GFFeature.feature_name
        return "gf"
      end
      def GFFeature.sql_type
        return "VARCHAR(20)"
      end
      def GFFeature.feature_type
        return "syn"
      end

      ################
      private

      def compute_feature_instanceOK
        unless @@target_gfs
          return nil
        end

        @@target_gfs.each { |rel, other_node|
          if @@node == other_node
            return rel
          end
        }

        return nil
      end
    end
  end
end
