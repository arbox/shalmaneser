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
require "FredSplitPkg"

class FredSplit

  ###
  # new
  #
  # evaluate runtime options and announce the task
  def initialize(exp_obj, # FredConfigData object
		 options, # hash: runtime option name (string) => value(string)
                 ignore_unambiguous = false)

    in_enduser_mode_unavailable()

    @exp = exp_obj
    @ignore_unambiguous = ignore_unambiguous

    # evaluate runtime options
    @split_id = nil
    @trainpercent = 0.9

    options.each_pair { |opt, arg|
      case opt
      when "--logID"
	@split_id = arg

      when "--trainpercent"
	@trainpercent = arg.to_f / 100.0

      else
	# case of unknown arguments has been dealt with by fred.rb
      end
    }

    # sanity check: need a log ID
    if @split_id.nil?
      raise "I need a log ID, parameter --logID"
    end
    if @trainpercent <= 0.0 or @trainpercent >= 1.0
      raise "Training percentage needs to be between 1 and 99. I got "+
	(@trainpercent * 100.0).to_i.to_s
    end

    ##
    # make a splitting object
    @split_obj = FredSplitPkg.new(@exp)

    # announce the task
    $stderr.puts "---------"
    $stderr.puts "Fred  experiment #{@exp.get("experiment_ID")}: Making split, using " + (@trainpercent * 100.0).to_i.to_s + "% as training data."
    $stderr.puts "---------"
  end

  def FredSplit.remove_split(exp,      # FredConfigData object
                             splitID)  # string: split ID

    FredSplitPkg.remove_split(exp, splitID)
  end

  ###
  # compute
  #
  # do the splitting
  def compute()
    FredSplit.remove_split(@exp, @split_id)
    @split_obj.make_new_split(@split_id, @trainpercent,
                              @ignore_unambiguous)
  end
end
