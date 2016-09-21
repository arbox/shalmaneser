require 'rosy/second_phase_feature_extractor'

module Shalmaneser
  module Rosy

    ##############################################
    # Individual feature extractors
    ##############################################

    ####################
    # nearestNode
    #
    # compute whether if my head word is the nearest word to the target,
    # according to some criterion

    class NearestNodeFeature < SecondPhaseFeatureExtractor
      NearestNodeFeature.announce_me

      def self.designator
        return "nearest_node"
      end

      def self.feature_names
        return ["nearest_pt_path",  # the nearest node with a specific pt_path
                "neareststring_pt",# the nearest pt (string distance)
                "nearestpath_pt"]   # the nearest pt (path length) ]
      end

      def NearestNodeFeature.sql_type
        return "TINYINT"
      end

      def NearestNodeFeature.feature_type
        return "syn"
      end

      #####
      private

      def NearestNodeFeature.extractor_list
        return ["worddistance","pt_path","pt","path_length"]
      end

      def compute_features_for_sentence(instance_features)

        # for each "interesting" feature, compute a hash map value -> index
        # also compute a hashmap index -> distance
        # so we efficiently compute, for each feature value, the index with min distance

        dist_hash = {} # node id -> word distance
        pl_hash   = {} # node id -> path length
        path_hash = {} # path -> node id array
        pt_hash = {}   # pt -> node id array

        result = [Array.new(instance_features.length),
                  Array.new(instance_features.length),
                  Array.new(instance_features.length)]

        instance_features.each_index {|inst_id|
          instance_hash = instance_features[inst_id]
          dist_hash[inst_id] = instance_hash["worddistance"]
          pl_hash[inst_id] = instance_hash["path_length"]

          # record paths
          pt_path = instance_hash["pt_path"]
          unless path_hash.key? pt_path
            path_hash[pt_path] = []
          end
          path_hash[pt_path] << inst_id

          # record pts
          pt = instance_hash["pt"]
          unless pt_hash.key? pt
            pt_hash[pt] = []
          end
          pt_hash[pt] << inst_id

        }

        # compute feature value for each instance of each path
        # nearest-path feature is feature 0 of the extractor.
        path_hash.each {|path,inst_ids|
          distances = inst_ids.map {|inst_id| dist_hash[inst_id]}
          min_dist = distances.min
          inst_ids.each {|inst_id|
            distance = dist_hash[inst_id]
            if distance == min_dist and path != @exp.get("noval")
              result[0][inst_id] = 1
            else
              result[0][inst_id] = 0
            end
          }
        }

        # nearest-pt (string dist) feature is feature 1 of the extractor
        pt_hash.each{|pt,inst_ids|
          distances = inst_ids.map {|inst_id| dist_hash[inst_id]}
          min_dist = distances.min
          inst_ids.each {|inst_id|
            distance = dist_hash[inst_id]
            if distance == min_dist and pt != @exp.get("noval")
              result[1][inst_id] = 1
            else
              result[1][inst_id] = 0
            end
          }
        }

        # nearest-pt (path length) feature is feature 2 of the extractor
        pt_hash.each{|pt,inst_ids|
          path_lengths = inst_ids.map {|inst_id| pl_hash[inst_id]}
          min_pl = path_lengths.min
          inst_ids.each {|inst_id|
            path_length = pl_hash[inst_id]
            if path_length == min_pl and pt != @exp.get("noval")
              result[2][inst_id] = 1
            else
              result[2][inst_id] = 0
            end
          }
        }

        return result
      end
    end
  end
end
