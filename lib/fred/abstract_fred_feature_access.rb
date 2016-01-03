module Shalmaneser
  module Fred
    ########################################
    ########################################
    # Feature access classes:
    # read and write features
    class AbstractFredFeatureAccess
      ####
      def initialize(exp, # experiment file object
                     dataset, # dataset: "train" or "test"
                     mode = "r") # mode: r, w, a
        @exp = exp
        @dataset = dataset
        @mode = mode

        unless ["r", "w", "a"].include? @mode
          $stderr.puts "FeatureAccess: unknown mode #{@mode}."
          exit 1
        end

      end

      ####
      def AbstractFredFeatureAccess.remove_feature_files
        raise "overwrite me"
      end

      ####
      def write_item(lemma,  # string: lemma
                     pos,    # string: POS
                     ids,    # array:string: unique IDs of this occurrence of the lemma
                     sid,    # string: sentence ID
                     sense,  # string: sense
                     features) # features: hash feature type-> features (string-> array:string)
        raise "overwrite me"
      end

      def flush
        raise "overwrite me"
      end
    end
  end
end
