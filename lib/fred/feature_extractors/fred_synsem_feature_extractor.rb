require_relative 'fred_feature_extractor'

module Shalmaneser
  module Fred
    #####
    # syntax-plus-headword feature
    class FredSynsemFeatureExtractor < FredFeatureExtractor

      FredSynsemFeatureExtractor.announce_me

      def self.feature_name
        'synsem'
      end

      def each_feature(feature_hash)
        feature_hash.each do |ftype, fvalues|
          case ftype
          when "CH", "PA"
            # grf#word#lemma#pos#ne
            fvalues.each { |f| yield ftype + "SEM" + f }
          when "SI"
            # parentlemma#grf#word#lemma#pos#ne
            # remove parent lemma
            fvalues.each { |f| yield ftype + "SEM" + f.split("#")[1..-1].join("#") }
          else
            # not a syntax feature
          end
        end
      end
    end
  end
end
