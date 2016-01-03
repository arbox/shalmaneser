require_relative 'fred_feature_extractor'

module Shalmaneser
  module Fred
  #####
    # context feature: POS separately, small contexts only
    class FredContextPOSFeatureExtractor < FredFeatureExtractor
      FredContextPOSFeatureExtractor.announce_me

      def FredContextPOSFeatureExtractor.feature_name
        return "context_pos"
      end

      ###
      def initialize(exp)
        super(exp)

        # cxsizes: list of context sizes chosen as features,
        # encoded in metafeature labels
        # written in a hash for fast access
        @cxsizes = {}
        @exp.get_lf("feature", "context").each { |cxsize|
          if cxsize <= 10
            @cxsizes[ "CX" + cxsize.to_s ] = true
          end
        }
        if @cxsizes.empty?
          $stderr.puts "context_pos feature warning: will not be computed"
          $stderr.puts "as there is no context of size <= 10"
        end
      end

      ###
      def each_feature(feature_hash)
        # word#lemma#pos#ne
        pos_index = 2

        feature_hash.each { |ftype, fvalues|
          if @cxsizes[ftype]
            # this is a context feature of a size chosen
            # by the user for featurization

            fvalues.each { |f|
              yield "POS" + ftype + f.split("#")[pos_index]
            }
          end
        }
      end
    end
end
end
