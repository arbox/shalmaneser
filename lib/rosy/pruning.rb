######
# XpPrune
# Katrin Erk Jan 30, 2006
#
# Pruning for Rosy: mark constituents that as likely/unlikely to instantiate
# a role.
#
# Pruning currently available:
# Both Xue/Palmer original and a modified version for FrameNet

require "ruby_class_extensions"
require 'value_restriction'

module Shalmaneser
  module Rosy

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
      def self.prune?(exp)  # Rosy experiment file object
        if exp.get("prune")
          return true
        else
          return false
        end
      end

      ###
      # returns: string, the name of the pruning column
      #  nil if no pruning has been set
      def self.colname(exp)
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
      def self.restriction_removing_pruned(exp) # Rosy experiment file object
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
      def self.integrate_pruning_into_run(run_column, # string: run column name
                                          iterator,   # Iterator object
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
          all_noval = []
          view.each_instance_s { |inst|
            all_noval << exp.get("noval")
          }
          # and set all selected instances to noval
          view.update_column(run_column, all_noval)
          view.close
        }
      end
    end
  end
end
