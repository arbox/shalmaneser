require_relative 'fred_feature_extractor'

module Shalmaneser
  module Fred
    #####
    # context feature
    class FredContextFeatureExtractor < FredFeatureExtractor

      FredContextFeatureExtractor.announce_me

      def self.feature_name
        'context'
      end

      ###
      def initialize(exp)
        super(exp)

        # cxsizes: list of context sizes chosen as features,
        # encoded in metafeature labels
        # written in a hash for fast access
        @cxsizes = {}
        @exp.get_lf("feature", "context").each do |cxsize|
          @cxsizes["CX" + cxsize.to_s] = true
        end
      end

      ###
      def each_feature(feature_hash)
        # grf#word#lemma#pos#ne
        lemma_index = 2

        feature_hash.each do |ftype, fvalues|
          if @cxsizes[ftype]
            # this is a context feature of a size chosen
            # by the user for featurization

            fvalues.each do |f|
              next if f =~ /#####/
              yield ftype + f.split("#")[lemma_index]
            end
          end
        end
      end

    end
  end
end
