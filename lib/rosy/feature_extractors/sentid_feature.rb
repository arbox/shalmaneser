require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # admin feature: sentence ID
    class SentidFeature < SingleFeatureExtractor
      SentidFeature.announce_me

      def SentidFeature.feature_name
        return "sentid"
      end
      def SentidFeature.sql_type
        return "VARCHAR(100)"
      end
      def SentidFeature.feature_type
        return "admin"
      end
      def SentidFeature.info
        # additional info: I am an index feature
        return super().concat(["index"])
      end

      #####
      private

      def compute_feature_instanceOK
        return ::Shalmaneser::Rosy::construct_instance_id(@@sent.id, @@frame.id)
      end
    end
  end
end
