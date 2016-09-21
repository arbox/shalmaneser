require 'rosy/single_feature_extractor'
module Shalmaneser
  module Rosy
    ####################
    # gold role label
    class GoldlabelFeature < SingleFeatureExtractor
      GoldlabelFeature.announce_me

      def GoldlabelFeature.feature_name
        return "gold"
      end
      def GoldlabelFeature.sql_type
        return "VARCHAR(30)"
      end
      def GoldlabelFeature.feature_type
        return "gold"
      end
      def GoldlabelFeature.info
        # additional info: I am an index feature
        return super().concat(["index"])
      end

      ################
      private

      def compute_feature_instanceOK
        @@frame.each_fe_by_name {|fe|
          if fe.children.include? @@node
            return fe.name
          end
        }

        # no role label for this node
        # if @@split_nones
        # split "no role" label into:
        # before/after/dominating the target node
        #      return @@relpos
        #    else
        return nil
        #    end
      end
    end
  end
end
