require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # admin feature: frame assigned by FN
    class FrameFeature < SingleFeatureExtractor
      FrameFeature.announce_me

      def FrameFeature.feature_name
        return "frame"
      end
      def FrameFeature.sql_type
        return "VARCHAR(35)"
      end
      def FrameFeature.feature_type
        return "ubiq"
      end
      def FrameFeature.info
        # additional info: I am an index feature
        return super().concat(["index"])
      end

      #####
      private

      def compute_feature_instanceOK
        if @@frame
          return @@frame.name
        else
          return nil
        end
      end
    end
  end
end
