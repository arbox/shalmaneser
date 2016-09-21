require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    ################
    # voice of the target lemma
    class TargetVoiceFeature < SingleFeatureExtractor
      TargetVoiceFeature.announce_me

      def TargetVoiceFeature.feature_name
        return "target_voice"
      end
      def TargetVoiceFeature.sql_type
        return "CHAR(4)"
      end
      def TargetVoiceFeature.feature_type
        return "ubiq"
      end

      #####
      private

      def compute_feature_instanceOK
        voice = @@interpreter_class.voice(@@target)
        if voice
          return voice.slice(0,4)
        else
          return nil
        end
      end
    end
  end
end
