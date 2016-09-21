####
# ke & sp
# adapted to new feature extractor class,
# Collins and Tiger features combined:
# SP November 2005
#
# Feature Extractors for Rosy, Phase 2
#
# These are features that are computed on the basis of the Phase 1 feature set
#
# This consists of all features which have to know feature values for other nodes
# (e.g. am I the nearest node to the target?) or similar.
#
# Contract: each feature extractor inherits from the RosyPhase2FeatureExtractor class
#
# Feature extractors return nil if no feature value could be returned


# Salsa packages
require_relative 'abstract_feature_extractor'

################################
# base class for all following feature extractors
module Shalmaneser
  module Rosy
    class SecondPhaseFeatureExtractor < AbstractFeatureExtractor

      ###
      # we do not overwrite "train" and "refresh" --
      # this is just for features which have to train external models on aspects of the data

      ###
      # returns a string: "phase 1" or "phase 2",
      # depending on whether the feature is computed
      # directly from the SalsaTigerSentence and the SynNode objects
      # or whether it is computed from the phase 1 features
      # computed for the training set
      #
      # Here: all features in this packages are phase 2
      def self.phase
        "phase 2"
      end

      ###
      # returns an array of strings, providing information about
      # the feature extractor
      def self.info
        super().concat(["rosy"])
      end

      ###
      # set sentence, set node, set general settings: this is done prior to
      # feature computation using compute_feature_value()
      # such that computations that stay the same for
      # several features can be done in advance
      def self.set(var_hash)
        @@split_nones = var_hash["split_nones"]
        return true
      end

      # check if the current feature is computable, i.e. if all the necessary
      # Phase 1 features are in the present model..
      def self.is_computable(given_extractor_list)
        (extractor_list - given_extractor_list).empty?
      end

      # this probably has to be done for each feature:
      # identify sentences and the target, and recombine into a large array
      def compute_features_on_view(view)
        result = Array.new(self.class.feature_names.length)
        result.each_index {|i|
          result[i] = []
        }
        view.each_sentence {|instance_features|
          sentence_result = compute_features_for_sentence(instance_features)
          if result.length != sentence_result.length
            raise "Error: number of features computed for a sentence is wrong!"
          else
            result.each_index {|i|
              if sentence_result[i].length != instance_features.length
                raise "Error: number of feature values does not match number of sentence instances!"
              end
              result[i] += sentence_result[i]
            }
          end
        }
        return result
      end

      private

      # list of all the Phase 1 extractors that a particular feature extractor presupposes
      def self.extractor_list
        []
      end

      # compute the feature values for all instances of one sentence
      # left to be specified
      # returns (see AbstractFeatureAndExternal) an array of columns (arrays)
      # The length of the array corresponds to the number of features
      def compute_features_for_sentence(instance_features) # array of hashes features -> values
        raise "Overwrite me"
      end
    end
  end
end
