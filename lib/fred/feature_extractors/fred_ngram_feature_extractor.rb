require_relative 'fred_feature_extractor'

module Shalmaneser
  module Fred
    #####
    # bigram/trigram feature
    class FredNgramFeatureExtractor < FredFeatureExtractor

      FredNgramFeatureExtractor.announce_me

      def self.feature_name
        'ngram'
      end

      ###
      def initialize(exp)
        super(exp)

        # cxsize: context size from which the ngram feature will be computed
        # encoded in metafeature labels
        # written in a hash for fast access
        @cxsize = @exp.get_lf("feature", "context").detect do |cxsize|
          cxsize >= 2
        end

        unless @cxsize
          $stderr.puts "Warning: no context of size >= 2, so"
          $stderr.puts "no ngram feature computed."
        end
      end

      ###
      def each_feature(feature_hash)
        # word#lemma#pos#ne
        lemma_index = 1
        pos_index = 2

        feature_hash.each do |ftype, fvalues|
          if ftype == "CX" + @cxsize.to_s
            # compute the ngram features from this context
            # |fvalues| = 2*cxsize, that is, cxsize describes
            # the length of a one-sided context window
            # the bigram of features around the target
            # concerns fvalues[cxsize-1] and fvalues[cxsize]
            # the trigram of two words before, one word after includes
            # fvalues[cxsize-2], fvalues[cxsize-1] and fvalues[cxsize]

            [
              [[-1, 0], "BLEM", lemma_index], # bigram of lemmas
              [[-1, 0], "BPOS", pos_index],   # bigram of POSs
              [[-2, -1, 0], "TLEM", lemma_index], # trigram of lemmas
              [[-2, -1, 0], "TPOS", pos_index] # trigram of POSs
            ].each do |f_indices, label, subindex|
              fs = f_indices.map { |i| fvalues[@cxsize+i] }.compact
              if fs.length == f_indices.length
                # we successfully extracted entries for all the given indices
                yield label + fs.map { |f| f.split("#")[subindex] }.join
              end
            end
          end
        end
      end
    end
  end
end
