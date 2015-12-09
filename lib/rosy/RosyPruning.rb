######
# XpPrune
# Katrin Erk Jan 30, 2006
#
# Pruning for Rosy: mark constituents that as likely/unlikely to instantiate
# a role.
#
# Pruning currently available:
# Both Xue/Palmer original and a modified version for FrameNet

require "common/ruby_class_extensions"

require "rosy/RosyFeatureExtractors"
# require "common/RosyConventions"
require 'common/value_restriction'
require 'common/configuration/rosy_config_data'
require "rosy/RosyIterator"

###
# Pruning, derived from the Xue/Palmer algorithm
#
# implemented in the Interpreter Class of each individual parser
class PruneFeature < RosySingleFeatureExtractor
  PruneFeature.announce_me

  def self.feature_name
    "prune"
  end

  def self.sql_type
    "TINYINT"
  end

  def self.feature_type
    'syn'
  end

  def self.info
    # additional info: I am an index feature
    super().concat(["index"])
  end

  ################
  private

  def compute_feature_instanceOK
    retv = @@interpreter_class.prune?(@@node, @@paths, @@terminals_ordered)
    if [0, 1].include? retv
      return retv
    else
      return 0
    end
  end
end

####################
# HIER changeme
class TigerPruneFeature < RosySingleFeatureExtractor
  TigerPruneFeature.announce_me()

  def TigerPruneFeature.feature_name()
    return "tiger_prune"
  end
  def TigerPruneFeature.sql_type()
    return "TINYINT"
  end
  def TigerPruneFeature.feature_type()
    return "syn"
  end
  def TigerPruneFeature.info()
    # additional info: I am an index feature
    return super().concat(["index"])
  end

  ################
  private

  def compute_feature_instanceOK()
    if @@changeme_tiger_include.include? @@node
      return 1
    else
      return 0
    end
  end
end




#######################3
# Pruning:
# packaging all methods that will be needed to
# implement it,
# given that the xp_prune feature defined above
# has been computed for each constituent during featurization.
class Pruning

  ###
  # returns true if some kind of pruning has been set in the experiment file
  #  else false
  def Pruning.prune?(exp)  # Rosy experiment file object
    if exp.get("prune")
      return true
    else
      return false
    end
  end

  ###
  # returns: string, the name of the pruning column
  #  nil if no pruning has been set
  def Pruning.colname(exp)
    if exp.get("prune")
      return exp.get("prune")
    else
      return nil
    end
  end

  ###
  # make ValueRestriction according to the pruning option set in
  # the experiment file:
  #       WHERE <pruning_column_name> = 1
  # where <pruning_column_name> is the name of one of the
  # pruning features defined above, the same name that has
  # been set as the value of the pruning parameter in the experiment file
  #
  # return: ValueRestriction object (see RosyConventions)
  #  If no pruning has been set in the experiment file, returns nil
  def Pruning.restriction_removing_pruned(exp) # Rosy experiment file object
    if (method = Pruning.colname(exp))
      return ValueRestriction.new(method, 1)
    else
      return nil
    end
  end

  ###
  # given the name of a DB table column and an iterator that
  # iterates over some data,
  # assuming that the column describes some classifier run results,
  # choose all rows where the pruning column is 0 (i.e. all instances
  # that have been pruned away) and set the value of the given column
  # to noval for them all, marking them as "not assigned any role".
  def Pruning.integrate_pruning_into_run(run_column, # string: run column name
                                         iterator,   # RosyIterator object
                                         exp)        # Rosy experiment file object
    unless Pruning.prune?(exp)
      # no pruning activated
      return
    end

    iterator.each_group { |group_descr_hash, group|
      # get a view of all instances for which prune == 0, i.e. that have been pruned away
      view = iterator.get_a_view_for_current_group(
                                                   [run_column],
                                                   [ValueRestriction.new(Pruning.colname(exp), 0)]
                                                   )
      # make a list of column values that are all noval
      all_noval = Array.new
      view.each_instance_s { |inst|
        all_noval << exp.get("noval")
      }
      # and set all selected instances to noval
      view.update_column(run_column, all_noval)
      view.close()
    }
  end
end
