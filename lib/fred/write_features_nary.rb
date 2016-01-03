require 'fred/FredConventions' # !
module Shalmaneser
  module Fred
    ##############
    # write features,
    # either lemma-wise
    # or lemma+sense-wise
    # if lemma+sense-wise, write as binary classifier,
    # i.e. map the target senses
    #
    # Use Delegator.
    ###
    # Features for N-ary classifiers
    class WriteFeaturesNary
      def initialize(lemma,
                     exp,
                     dataset,
                     feature_dir)

        @filename = feature_dir + ::Shalmaneser::Fred.fred_feature_filename(lemma)
        @f = File.new(@filename, "w")
        @handle_multilabel = exp.get("handle_multilabel")
      end

      def write_instance(features, senses)
        @f.print features.map { |x|
          x.to_s.gsub(/,/, "COMMA").gsub(/;/, "SEMICOLON")
        }.join(",")

        # possibly more than one sense? then use semicolon to separate
        if @handle_multilabel == "keep"
          # possibly more than one sense:
          # separate by semicolon,
          # and hope that the classifier knows this
          @f.print ";"
          @f.puts senses.map {|x|
            x.to_s.gsub(/,/, "COMMA").gsub(/;/, "SEMICOLON")
          }.join(",")
        else
          # one sense: just separate by comma
          @f.print ","
          @f.puts senses.first.to_s.gsub(/,/, "COMMA").gsub(/;/, "SEMICOLON")
        end
      end

      def close
        @f.close
      end
    end
  end
end
