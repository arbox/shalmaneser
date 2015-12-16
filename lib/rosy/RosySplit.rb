# RosySplit
# KE, SP May 05
#
# One of the main task modules of Rosy:
# split training data into training and test parts
#
# A split is realized as two DB tables,
# one with the sentence IDs of the training part of the split,
# and one with the sentence IDs of the test part of the split.
#
# Additionally, each split table also contains all phase-2 features
# for the train/test part of the split:
# Phase 2 features are trained on training features and applied to
# test features. They need to be retrained for each split.

require "ruby_class_extensions"

# Frprep packages
require 'configuration/prep_config_data'

# Rosy packages
require "rosy/FailedParses"
# require "rosy/FeatureInfo"
# require "RosyConventions"
require 'rosy/var_var_restriction'
require "rosy/RosyIterator"
require "rosy/RosyTask"
# require "rosy/RosyTrainingTestTable"
# require "rosy/View"

class RosySplit < RosyTask

  def initialize(exp,      # RosyConfigData object: experiment description
                 opts,     # hash: runtime argument option (string) -> value (string)
                 ttt_obj)  # RosyTrainingTestTable object
    ##
    # remember the experiment description

    @exp = exp
    @ttt_obj = ttt_obj


    ##
    # check runtime options

    # default values
    @trainpercent = 90
    @splitID = nil

    opts.each do |opt,arg|
      case opt
      when "--trainpercent"
        @trainpercent = arg.to_i
      when "--logID"
        @splitID = arg
      else
        # this is an option that is okay but has already been read and used by rosy.rb
      end
    end

    #sanity checks
    if @splitID.nil?
      raise "I need an ID for the split in order to proceed. Parameter: --logID|-l"
    end
    if @trainpercent <= 0 or @trainpercent >= 100
      raise "--trainpercent must be between 1 and 99."
    end

    # add preprocessing information to the experiment file object
    # so we know what language the training data is in
    preproc_filename = @exp.get("preproc_descr_file_train")
    if not(preproc_filename)
      $stderr.puts "Please set the name of the preprocessing exp. file name"
      $stderr.puts "in the experiment file, parameter preproc_descr_file_train."
      exit 1
    elsif not(File.readable?(preproc_filename))
      $stderr.puts "Error in the experiment file:"
      $stderr.puts "Parameter preproc_descr_file_train has to be a readable file."
      exit 1
    end

    # @todo Add features for Rosy and delete this dependency.
    preproc_exp = ::Shalmaneser::Configuration::FrPrepConfigData.new(preproc_filename)
    @exp.adjoin(preproc_exp)

    # announce the task
    $stderr.puts "---------"
    $stderr.puts "Rosy experiment #{@exp.get("experiment_ID")}: Making split with ID #{@splitID}, training data percentage #{@trainpercent}%"
    $stderr.puts "---------"
  end

  #####
  # perform
  #
  # perform a split of the training data and the "failed sentences" object
  # the split is written to a DB table, the failed sentence splits are written to files
  def perform()

    #################################
    # 1. treat the failed sentences
    perform_failed_parses()

    ###############################
    # 2. get the main table, split it, and write the result to two new tables
    perform_make_split()

    ###############################
    # 3. Repeat the training and extraction of phase 2 features for this split,
    #    and write the result to the split tables

  end

  #######
  # split index column name
  def RosySplit.split_index_colname()
    return "split_index"
  end

  ############
  # make_join_restriction
  #
  # Given a splitID, the main table to be split,
  # the dataset (train or test), and the experiment file object,
  # make a ValueRestriction object that can be passed to a view initialization:
  #
  # restrict main table rows to those that occur in the correct part
  # (part = train or part = test) of the split with the given ID
  #
  # returns: VarVarRestriction object
  def RosySplit.make_join_restriction(splitID,  # string: splitlogID
                                      table,    # DBtable object
                                      dataset,  # string: "train", "test"
                                      ttt_obj)  # RosyTrainingTestTable object

    return VarVarRestriction.new(table.table_name + "." + table.index_name,
                                 ttt_obj.splittable_name(splitID, dataset) + "." + RosySplit.split_index_colname())

  end

  ###########
  private

  ##########
  # perform_failed_parses:
  #
  # this is the part of the perform() method
  # that splits the sentences with failed parses
  # into a training and a test part
  # and remembers this split
  def perform_failed_parses()
    # read file with failed parses
    failed_parses_filename =
          File.new_filename(@exp.instantiate("rosy_dir",
                                             "exp_ID" => @exp.get("experiment_ID")),
                            @exp.instantiate("failed_file",
                                             "exp_ID" => @exp.get("experiment_ID"),
                                             "split_ID" => "none",
                                             "dataset" => "none"))


    fp_obj = FailedParses.new()
    fp_obj.load(failed_parses_filename)

    # split and write to appropriate files
    fp_train_obj, fp_test_obj = fp_obj.make_split(@trainpercent)

    train_filename =
         File.new_filename(@exp.instantiate("rosy_dir",
                                            "exp_ID" => @exp.get("experiment_ID")),
                           @exp.instantiate("failed_file",
                                            "exp_ID" => @exp.get("experiment_ID"),
                                            "split_ID" => @splitID,
                                            "dataset" => "train"))

    fp_train_obj.save(train_filename)

    test_filename =
        File.new_filename(@exp.instantiate("rosy_dir",
                                           "exp_ID" => @exp.get("experiment_ID")),
                          @exp.instantiate("failed_file",
                                           "exp_ID" => @exp.get("experiment_ID"),
                                           "split_ID" => @splitID,
                                           "dataset" => "test"))

    fp_test_obj.save(test_filename)
  end

  ##########
  # perform_make_split
  #
  # this is the part of the perform() method
  # that makes the actual split
  # at random and stores it in new database tables
  def perform_make_split()
    $stderr.puts "Making split with ID #{@splitID}"

    # get a view of the main table
    maintable = @ttt_obj.existing_train_table()

    # construct new DB tables for the train and test part of the new split:
    # get table name and join column name
    split_train_table = @ttt_obj.new_split_table(@splitID, "train", RosySplit.split_index_colname())
    split_test_table =  @ttt_obj.new_split_table(@splitID, "test", RosySplit.split_index_colname())

    # make split: put each sentence ID into either the train or the test table
    # based on whether a random number btw. 0 and 100 is larger than @trainpercent or not


    # go through training data one frame at a time
    iterator = RosyIterator.new(@ttt_obj, @exp, "train", "xwise"=>"frame")
    iterator.each_group { |dummy1, dummy2|
      view = iterator.get_a_view_for_current_group(["sentid", maintable.index_name])
      view.each_sentence() { |sentence|
        if rand(100) > @trainpercent
          # put this sentence into the test table
          table = split_test_table
        else
          # put this sentence into the training table
          table = split_train_table
        end
        sentence.each { |instance|
          table.insert_row([[RosySplit.split_index_colname(), instance[maintable.index_name]],
                            ["sentid", instance["sentid"]]])
        }
      }
      view.close()
    }
  end

end
