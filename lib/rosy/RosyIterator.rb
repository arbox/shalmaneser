# RosyIterator
# KE May 2005
#
# RosyIterator is a class that
# * reads the "xwise" parameters in the experiment file to
#   determine the portions in which data is to be fed to classifiers,
#   and offers an iterator that iterates through every group to
#   be trained/tested on
# * constructs views matching the given "xwise" group.
#
# RosyIterator incorporates the following services:
# - choosing the right DB table, depending on
#   whether training/test data is being accessed,
#   and with or without a splitlog
# - making and adding all currently available Dynamic Gold objects
#   (i.e. objects that are capable of mapping the gold column to
#   something else)
# - initializing a view, potentially modified depending on the assignment step:
#   argrec -> use dynamic gold, mapping gold labels to "FE" or "NONE"
#   arglab -> use only those rows that have "FE" assigned from the argrec step
#
# Setting "xwise": An "xwise" entry in the hash passed on to RosyIterator.new()
# overrides all other settings. If that isn't given, the "xwise_" + step
# (xwise_argrec, xwise_arglab, xwise_onestep) from the experiment file is read.
# If that hasn't been set either, the default is frame-wise.

require 'common/ruby_class_extensions'

# require 'rosy/View'
# require "common/RosyConventions"
require 'common/value_restriction'
require 'db/select_table_and_columns'
# require "rosy/RosyPruning"
require "rosy/RosySplit"
require "rosy/RosyTrainingTestTable"

class RosyIterator

  ###
  # new
  #
  # open the correct database table,
  # initialize Dynamic Gold objects


  def initialize(ttt_obj, # RosyTrainingTestTable object
                 exp,     # RosyConfigData object: experiment file
                 dataset, # string: train/test
                 var_hash = {}) # further arguments:
    # step: string: argrec/arglab/onestep, or nil (= no manipulation of the view)
    # testID: string: ID of test set, or nil
    # splitID string: splitlog ID, or nil if no split is to be used
    # xwise: string: containing any subset of frame/target_pos/target joined by spaces,
    #                overrides @exp.get("xwise_" + @step) if non-nil
    # prune: boolean: if pruning has been chosen in the experiment file,
    #                make a value restriction that omits pruned instances

    @exp = exp
    @dataset = dataset
    @ttt_obj = ttt_obj
    @splitID = var_hash["splitID"]
    @step = var_hash["step"]
    @testID = var_hash["testID"]

    # object variables we are going to use below
    @db_table = nil  # DB table we are working on
    @allcolnames = nil   # names of all columns of first and potentially second table

    @dyn_gold_objects = nil # list of dynamic gold-producing object
    @standard_dyngold_id = nil # ID of standard dyngold obj to use

    @standard_value_restrictions = [] #value restrictions to use with each view

    @second_table = nil      # read view from 2 tables? if so, DBTable object for 2nd table
    @use_cols_from_second_table = nil # array: names of columns from 2nd table
    @second_table_colprefix = nil     # string: prefix for columns from 2nd table

    @xwise = nil # array: read data one X at a time (forms groups)
    @groups = nil # distinct values for X from xwise
    @current_group = nil # current group (will be set by iterator each_group)

    ##
    # open the right database table
    if @dataset == "train" or @splitID
      @db_table = @ttt_obj.existing_train_table()

    else
      unless @testID
        raise "cannot open the test table without test ID"
      end
      @db_table = @ttt_obj.existing_test_table(@testID)
    end
    @allcolnames = @db_table.list_column_names()

    ##
    # make dynamic gold objects
    @dyn_gold_objects = Array.new
    @dyn_gold_objects << DynGoldBinary.new(@exp.get("noval"))

    ###
    # what is the standard gold column to be returned?
    if @step == "argrec"
      # argument recognition: distinguish just "FE", "NONE" as gold
      @standard_dyngold_id = "binary_gold"
    end

    ##
    # if splitID has been set,
    # make additional restrictions on the column values
    if @splitID
      # get split table name
      @second_table = @ttt_obj.existing_split_table(@splitID, @dataset, RosySplit.split_index_colname())

      # additional value restriction:
      # only use rows whose sentence ID also appears in the split table
      # (i.e. rows included in the split)
      @standard_value_restrictions << RosySplit.make_join_restriction(@splitID,
                                                                      @db_table,
                                                                      @dataset,
                                                                      @ttt_obj)

      # additional column names:
      # those of the second table (but remove duplicates)
      @allcolnames.concat @ttt_obj.existing_split_table(@splitID, @dataset, RosySplit.split_index_colname()).list_column_names()
      @allcolnames.uniq!


      # if we're using a split, read the phase 2 features and the classification results
      # from the split table rather than from the main table:
      # @use_cols_from_second_table is a list of column names (strings)
      #     to take from the 2nd table
      # @second_table_colprefix is a string: all columns starting with this prefix
      #     are taken from the 2nd table
      @use_cols_from_second_table = [ RosySplit.split_index_colname() ]
      @second_table_colprefix = @exp.get("classif_column_name")
    end

    ###
    # Any (row) value restrictions to be imposed
    # on all views we generate?
    if @step == "arglab"
      # argument labeling: use as input only those lines
      # for which argrec-label is "FE"

      if @exp.get("assume_argrec_perfect")
        # assume perfect argrec step:
        # take all rows where gold is not "noval"
        @standard_value_restrictions << ValueRestriction.new(@db_table.table_name + ".gold",
                                                             @exp.get("noval"),
                                                             "posneg" => "!=")
      else
        # use argrec step as is:
        # take all rows where the argrec result is "FE"

        case @dataset
        when "train"
          run_column_name = @ttt_obj.existing_runlog("argrec", "train", nil, @splitID)
        when "test"
          run_column_name = @ttt_obj.existing_runlog("argrec", "test", @testID, @splitID)
        else
          raise "Shouldn't be here"
        end

        if run_column_name.nil?
          $stderr.puts "Missing: argrec classification results on #{@dataset} data."
          $stderr.puts "I have logs of the following runs: "
          $stderr.puts @ttt_obj.runlog_to_s()
          raise "Problem"
        end

        # run column where? split table, or the table we are mainly working with?
        if @second_table
          run_column_name = @second_table.table_name + "." + run_column_name
        else
          run_column_name = @db_table.table_name + "." + run_column_name
        end

        @standard_value_restrictions << ValueRestriction.new(run_column_name, "FE")
      end
    end

    # pruning?
    if var_hash["prune"] and    # pruning requested in RosyIterator initialization
        ["argrec", "onestep"].include? @step and # pruning only affects argument recognition
        Pruning.prune?(@exp)    # pruning has been set in the experiment file
       @standard_value_restrictions << Pruning.restriction_removing_pruned(@exp)
    end

    ##
    # access "xwise" information
    # are we training by frame or by target POS or target lemma?

    # xwise-value in var_hash overrides others
    @xwise = var_hash["xwise"]
    unless @xwise
      if @step
        # read xwise from experiment file,
        # if we know what training/test step we're in
        @xwise = @exp.get("xwise_" + @step)
      end
    end
    if @xwise.nil?
      # default: read one frame at a time
      @xwise = "frame"
    end

    # xwise is a string consisting of any subset of
    # "frame", "target_pos", "target" joined by spaces.
    # transform to an array by splitting at spaces
    @xwise = @xwise.split()
    @xwise.each { |xwise_entry|
      unless @ttt_obj.feature_names.include? xwise_entry
        # sanity check: valid xwise value?
        raise "Unknown value for parameter 'xwise' in experiment file.\n" +
              "Allowed: any subset of the list of features listed in the experiment file.\n" +
              "This is the granularity of training and testing\n" +
               "What I got was: " + @xwise.join(" ")
      end
    }

    # list all frames/ all target POSs/all frame+target-pairs
    @groups = unique_values_of_columns(@xwise)
    @current_group = nil
  end

  ####
  # get_xwise_column_names
  #
  # get the column names used for determining the groups
  #
  # returns: an array of strings, ["frame"] or ["frame", "target"],
  # or ["target_pos"]
  def get_xwise_column_names()
    return @xwise
  end

  ####
  # num_groups
  # returns: integer
  def num_groups()
    return @groups.length()
  end

  ####
  # each_group
  #
  # iterates through the "xwise" groups, sets
  # internal values such that get_a_view_for_current_group()
  # will get you the correct view
  #
  # yields: for each group, a pair of
  # - the hash describing the group, as returned by unique_values_of_column
  # - plus an ID for the group, made up of its hash values concatenated into a string
  #   (values are connected by spaces)
  def each_group()
    @groups.each { |hash|
      # hash is a hash column_name(string)-> value(object)
      # this is the unique description of the current group
      @current_group = hash
      yield [hash, hash.values.join(" ")]
    }
  end

  ####
  # get_a_view_for_current_group
  #
  # constructs a new View object
  # matching the last yielded group (of each_group)
  #
  # you give it: the names of the columns to be included in the view
  # (or "*" for all columns) and a list of value restrictions
  # on the rows (ValueRestriction objects, equalities or inequalities
  # column_name = value, columnb_name != value), which may be omitted
  #
  # returns: DBView object
  # @param columns [Array] array:string, column names to include
  #   or string: "*" for all columns
  # @param value_restrictions [Array] array:ValueRestriction objects
  def get_a_view_for_current_group(columns, value_restrictions = [])
    get_a_view_for_group(@current_group, columns, value_restrictions)
  end

  ####
  # get_a_view_for_group
  #
  # constructs a new View object
  # matching the a group given by its row hash
  # (as yielded by each_group)
  #
  # you give it: the group description hash,
  # the names of the columns to be included in the view
  # (or "*" for all columns) and a list of value restrictions
  # on the rows (ValueRestriction objects, equalities or inequalities
  # column_name = value, columnb_name != value), which may be omitted
  #
  # returns: DBView object
  # @param group [Hash] column(string)->value(object)
  #   describing the group
  # @param columns [Array] array:string, column names to include
  #   or string: "*" for all columns
  # @param value_restrictions [Array]  of ValueRestriction objects
  def get_a_view_for_group(group, columns, value_restrictions = [])

    # value_restrictions needs to be an array
    if value_restrictions.nil?
      value_restrictions = []
    end

    # we need to add value restrictions that say
    # that the group column names need to have the values for
    # the given group.
    # however, group column names may belong to either the first or
    # the second table

    # separate group column names into two groups
    first_columns, second_columns =
         separate_into_1st_and_2nd_table_cols(group.keys)

    # make separate value restrictions for the two groups
    value_restrictions = value_restrictions + first_columns.map {|column_name|
      ValueRestriction.new(column_name, group[column_name])
    }
    if second_columns
      unless @second_table
        raise "Cannot use second table columns without second table"
      end
      value_restrictions.concat second_columns.map { |column_name|
        ValueRestriction.new(@second_table.table_name + "." + column_name,
                             group[column_name],
                             "table_name_included" => true)
      }
    end

    # get a view with the given columns, given value restrictions
    # plus add more value restrictions: must be the current group
    return get_a_view(columns,value_restrictions)
  end



  ####
  # get_a_view
  #
  # construct a new View object,
  #
  # you give it: the names of the columns to be included in the view
  # (or "*" for all columns) and a list of value restrictions
  # on the rows (ValueRestriction objects, equalities or inequalities
  # column_name = value, columnb_name != value), which may be omitted
  #
  # returns: DBView object
  def get_a_view(columns, # array:strings, list of column names
                           # or string "*" (all columns)
                 value_restrictions = []) # array: ValueRestriction objects
                           # or [], nil for no restrictions

    if value_restrictions.nil?
      value_restrictions = []
    end
    return get_a_view_aux(columns, value_restrictions,
                          "gold" => "gold",
                          "dynamic_feature_list" => @dyn_gold_objects,
                          "standard_dyngold_id" => @standard_dyngold_id,
                          "sentence_id_feature" => "sentid")
  end

  ####
  # unique_values_of_columns
  #
  # construct a new View object
  # for the given column and
  # get all unique values for it
  #
  # returns: a list of hashes, one for each unique set of values
  def unique_values_of_columns(columns) # array:string, several column names
    retv = Array.new

    view = get_a_view_aux(columns, [],
                          "distinct" => true)

    view.each_hash() { |row|
      retv << row
    }
    view.close()
    return retv
  end

  #############################################
  private

  ###
  # given a list of column names,
  # separate them into first table and second table columns
  #
  # columns may be either an array of string (column names)
  # or the string "*" for "all columns"
  def separate_into_1st_and_2nd_table_cols(columns)

    if @use_cols_from_second_table or @second_table_colprefix
      # if there are columns I'm supposed to take from the second
      # table rather than the first, let's do that
      if columns == "*"
        # we have simply been told to use all columns
        columns = @allcolnames
      end

      # second table columns either start with @second_table_colprefix
      # or are in the list @use_columns_from_second_table
      second_columns, first_columns = columns.distribute { |colname|
        (@second_table_colprefix and colname =~ /^#{@second_table_colprefix}/) or
          (@use_cols_from_second_table and @use_cols_from_second_table.include?(colname))
      }

    else
      # no columns to take from a 2nd table
      first_columns = columns
      second_columns = nil
    end

    return [first_columns, second_columns]
  end

  ###
  # access DB table:
  # figure out which table, set of columns from that table,
  # set of columns from secondary table
  #
  # columns: either array of strings or "*"
  #
  def get_a_view_aux(columns,
                     value_restrictions,
                     var_hash)

    # distinguish main table and split table columns
    first_columns, second_columns = separate_into_1st_and_2nd_table_cols(columns)

    # make pairs of a DB table and the columns from that table
    tables_and_cols = [SelectTableAndColumns.new(@db_table, first_columns)]
    if @second_table
      tables_and_cols << SelectTableAndColumns.new(@second_table, second_columns)
    end


    # and get a view
    return DBView.new(tables_and_cols,
                      value_restrictions + @standard_value_restrictions,
                      @ttt_obj.database,
                      var_hash)
  end

end


###############
# class DynGoldBinary
#
# dynamic gold class:
# maps all FEs to "FE", and
# maps @noval to @noval.
#
# ID to hand to View in each_hash/each_array/each_sentence if you want
# to use this dynamic gold class:
# "binary_gold"
class DynGoldBinary
  def initialize(noval)
    @noval = noval
  end

  def make(gold)
    if gold == @noval
      return @noval
    else
      return "FE"
    end
  end

  def id()
    return "binary_gold"
  end
end
