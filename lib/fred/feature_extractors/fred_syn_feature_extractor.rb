require_relative 'fred_feature_extractor'

module Shalmaneser
  module Fred
    #####
    # syntax feature
    class FredSynFeatureExtractor < FredFeatureExtractor

      FredSynFeatureExtractor.announce_me

      def self.feature_name
        'syntax'
      end

      ###
      def each_feature(feature_hash)
        feature_hash.each do |ftype, fvalues|
          case ftype
          when "CH", "PA"
            grf_index = 0
            fvalues.each { |f| yield ftype + f.split("#")[grf_index] }
          when "SI"
            # parentlemma#grf#word#lemma#pos#ne
            grf_index = 1
            fvalues.each { |f| yield ftype + f.split("#")[grf_index] }
          else
            # not a syntactic metafeature
          end
        end
      end
    end
  end
end
