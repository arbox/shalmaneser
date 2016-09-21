require 'rosy/single_feature_extractor'

module Shalmaneser
  module Rosy
    # ################
    # # admin feature: word span of this constituent
    # class WordSpanFeature < SingleFeatureExtractor
    #   WordSpanFeature.announce_me()

    #   def WordSpanFeature.feature_name()
    #     return "wordspan"
    #   end
    #   def WordSpanFeature.sql_type()
    #     return "VARCHAR(30)"
    #   end
    #   def WordSpanFeature.feature_type()
    #     return "admin"
    #   end

    #   #####
    #   private

    #   def compute_feature_instanceOK()

    #     fwh = FeatureExtractor.headlemma(@@node_leftmost_terminal)
    #     lwh = FeatureExtractor.headlemma(@@node_rightmost_terminal)

    #     if fwh.nil?
    #       fwh = ""
    #     end
    #     if lwh.nil?
    #       lwh = ""
    #     end

    #     return  fwh+ "-" +lwh
    #   end
    # end
  end
end
