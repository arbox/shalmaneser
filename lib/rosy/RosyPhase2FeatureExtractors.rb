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
require 'rosy/AbstractFeatureAndExternal'
require 'common/SalsaTigerRegXML'

# Fred and Rosy packages
require "common/RosyConventions"


################################
# base class for all following feature extractors

class RosyPhase2FeatureExtractor < AbstractFeatureExtractor

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
  def RosyPhase2FeatureExtractor.phase()
    return "phase 2"
  end

  ###
  # returns an array of strings, providing information about
  # the feature extractor
  def RosyPhase2FeatureExtractor.info()
    return super().concat(["rosy"])
  end

  ###
  # set sentence, set node, set general settings: this is done prior to
  # feature computation using compute_feature_value()
  # such that computations that stay the same for
  # several features can be done in advance
  def RosyPhase2FeatureExtractor.set(var_hash)
    @@split_nones = var_hash["split_nones"]
    return true
  end

  # check if the current feature is computable, i.e. if all the necessary 
  # Phase 1 features are in the present model..
  def RosyPhase2FeatureExtractor.is_computable(given_extractor_list)
    return (eval(self.name()).extractor_list - given_extractor_list).empty?
  end
  
  # this probably has to be done for each feature:
  # identify sentences and the target, and recombine into a large array  
  def compute_features_on_view(view)
    result = Array.new(eval(self.class.name()).feature_names.length)
    result.each_index {|i|
      result[i] = Array.new
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
  def RosyPhase2FeatureExtractor.extractor_list()
    return []
  end

  # compute the feature values for all instances of one sentence
  # left to be specified
  # returns (see AbstractFeatureAndExternal) an array of columns (arrays)
  # The length of the array corresponds to the number of features
  def compute_features_for_sentence(instance_features) # array of hashes features -> values
    raise "Overwrite me"
  end


end


##############################################
# Individual feature extractors
##############################################

####################
# nearestNode
#
# compute whether if my head word is the nearest word to the target, 
# according to some criterion

class NearestNodeFeature < RosyPhase2FeatureExtractor
  NearestNodeFeature.announce_me()
  
  def NearestNodeFeature.designator()
    return "nearest_node"
  end
  def NearestNodeFeature.feature_names()
    return ["nearest_pt_path",  # the nearest node with a specific pt_path                         
            "neareststring_pt",# the nearest pt (string distance) 
            "nearestpath_pt"]   # the nearest pt (path length) ]
  end
  def NearestNodeFeature.sql_type()
    return "TINYINT"
  end
  def NearestNodeFeature.feature_type()
    return "syn"
  end

  #####
  private

  def NearestNodeFeature.extractor_list()
    return ["worddistance","pt_path","pt","path_length"]
  end
  
  def compute_features_for_sentence(instance_features)
    
    # for each "interesting" feature, compute a hash map value -> index
    # also compute a hashmap index -> distance
    # so we efficiently compute, for each feature value, the index with min distance 
    
    dist_hash = Hash.new # node id -> word distance
    pl_hash   = Hash.new # node id -> path length
    path_hash = Hash.new # path -> node id array
    pt_hash = Hash.new   # pt -> node id array
    
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
        path_hash[pt_path] = Array.new
      end
      path_hash[pt_path] << inst_id

      # record pts
      pt = instance_hash["pt"]
      unless pt_hash.key? pt
        pt_hash[pt] = Array.new
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

