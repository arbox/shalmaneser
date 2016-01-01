# FredSplit
# Katrin Erk April 05
#
# Frame disambiguation system:
# make random split of the training data
#
# The split is computed on the basis of the Fred format
# feature data.
# The split is recorded in a separate split directory
# with a very simple system:
# - one file per feature file, same filename
# - one line per instance line in feature file
# - entry in that line is either 'train' or 'test'

# Fred packages
require 'fred/fred_split_pkg'
require 'logging'

module Shalmaneser
  module Fred
    class FredSplit
      # @param [FredConfigData] exp
      # @param [String] split_id
      def self.remove_split(exp, split_id)
        FredSplitPkg.remove_split(exp, split_id)
      end

      ###
      # new
      #
      # evaluate runtime options and announce the task
      def initialize(exp_obj, # FredConfigData object
                     options, # hash: runtime option name (string) => value(string)
                     ignore_unambiguous = false)

        @exp = exp_obj
        @ignore_unambiguous = ignore_unambiguous

        # evaluate runtime options
        @split_id = nil
        @trainpercent = 0.9

        options.each_pair do |opt, arg|
          case opt
          when "--logID"
            @split_id = arg

          # @ todo AB: Should be prepared in the ConfigData/OptParser.
          when "--trainpercent"
            @trainpercent = arg.to_f / 100.0
          end
        end

        # sanity check: need a log ID
        # @todo AB: Move it to OptParser
        if @split_id.nil?
          raise "I need a log ID, parameter --logID"
        end

        # @todo AB: Move it to OptParser
        if @trainpercent <= 0.0 or @trainpercent >= 1.0
          raise "Training percentage needs to be between 1 and 99. I got "+
                (@trainpercent * 100.0).to_i.to_s
        end

        ##
        # make a splitting object
        @split_obj = FredSplitPkg.new(@exp)
      end

      ###
      # compute
      #
      # do the splitting
      def compute
        # announce the task
        LOGGER.info "Fred experiment #{@exp.get("experiment_ID")}: "\
                    "Making split, using #{(@trainpercent * 100.0).to_i}% as training data."

        FredSplitPkg.remove_split(@exp, @split_id)
        @split_obj.make_new_split(@split_id, @trainpercent,
                                  @ignore_unambiguous)
      end
    end
  end
end
