# Rosy TrainingTestTable
# Katrin Erk Jan 2006
#
# manage the training, test and split database tables
# of Rosy
#
# columns of training and test table:
# - index column (added by DbTable object itself)
# - one column per feature to be computed.
#   names of feature columns and their MySQL formats
#   are given by the RosyFeatureInfo object
# - columns for classification results
#   their names start with the classif_column_name entry
#   given in the experiment file
#   Their MySQL type is VARCHAR(20)
#
# columns of split tables:
# - sentence ID
# - index matching the training table index column
# - phase 2 features
#
# for all tables, training, test and split, there is 
# a list of learner application results,
# i.e. the labels assigned to instances by some learner
# in some learner application run.
# For the training table there are classification results for
# argrec applied to training data.
# For each split table there are classification results for 
# the test part of the split.
# For the test tables there are classification results for the test data.
# The runlog for each DB table lists the conditions of each run 
# (which model features, argrec/arglab/onestep, etc.)

require "common/ruby_class_extensions"

require 'db/db_table'
require "rosy/FeatureInfo"

# @note AB: Possibly this file belongs to <lib/db>. Check it!
######################
class RosyTrainingTestTable
  attr_reader :database, :maintable_name, :feature_names, :feature_info

  ######
  # data structures for this class
  # TttLog: contains known test IDs, splitIDs, runlogs for this 
  #         experiment.
  #  testIDs:  Array(string) known test IDs
  #  splitIDs: Array(string) known split IDs
  #  runlogs:  Hash tablename(string) -> Array:RunLog
  #            All classification runs for the given DB table,
  #            listing classification column names along with the
  #            parameters of the classification run
  #
  # RunLog: contains information for one classification run
  #  step: string argrec/arglab/onestep
  #  learner: string concatenation of names of learners used for this run
  #  modelfeatures: model features for this run, encoded into
  #            an integer: take the list of feature names for this experiment
  #            in alphabetical order, then set a bit to one if the
  #            corresponding feature is in the list of model features
  #  xwise: string, xwise for this classification run, 
  #            concatenation of the names of one or more 
  #            features (on which groups of instances 
  #            was the learner trained?)
  #  column: string, name of the DB table column with the results
  #            of this classification run
  #  okay: Boolean, false at first, set true on "confirm_runlog"
  #          Unconfirmed runlogs are considered nonexistent
  #          by existing_runlog, new_runlog, runlog_to_s
  TttLog = Struct.new("TttLog", :testIDs, :splitIDs, :runlogs)
  RunLog = Struct.new("RunLog", :step, :learner, :modelfeatures, :xwise, :column, :okay)


  ###
  def initialize(exp,      # RosyConfigData object
		 database) # Mysql object
    @exp = exp
    @feature_info = RosyFeatureInfo.new(@exp)
    @database = database

    ###
    # precompute values needed for opening tables:
    # name prefix of classifier columns
    @addcol_prefix = @exp.get("classif_column_name")
    # name of the main table
    @maintable_name = @exp.instantiate("main_table_name", 
				       "exp_ID" => @exp.get("experiment_ID"))
    # list of pairs [name, mysql format] for each feature (string*string)
    @feature_columns = @feature_info.get_column_formats()
    # list of feature names (strings)
    @feature_names = @feature_info.get_column_names()
    # make empty columns for classification results:
    # list of pairs [name, mysql format] for each classifier column (string*string)
    @classif_columns = Range.new(0,10).map {|id|
      [
	classifcolumn_name(id),
	"VARCHAR(20)"
      ]
    }
    # columns for split tables: 
    # the main table's sentence ID column.
    # later to be added: split index column copying the main table's index column
    @split_columns = @feature_columns.select { |name, type|
      name == "sentid"
    }

    ###
    # start the data structure for keeping lists of 
    # test and split IDs, classification run logs etc. 
    # test whether there is a pickle file.
    # if so, read it
    success = from_file()
    unless success
      # pickle file couldn't be read
      # initialize to empty object
      @log_obj = TttLog.new(Array.new, Array.new, Hash.new)
    end
  end

  ########
  # saving and loading log data
  def to_file(dir = nil)
    begin
      file = File.new(pickle_filename(dir), "w")
    rescue
      $stderr.puts "RosyTrainingTestTable ERROR: Couldn't write to pickle file " + pickle_filename(dir)
      $stderr.puts "Will not be able to remember new runs."
      return
    end
    Marshal.dump(@log_obj, file)
    file.close()
  end

  def from_file(dir = nil)
    filename = pickle_filename(dir)

    if File.exists?(filename)
      file = File.new(filename)
      begin
        @log_obj = Marshal.load(file)
      rescue 
        # something went wrong, for example an empty pickle file
        $stderr.puts "ROSY warning: could not read pickle #{filename}, assuming empty."
        return false
      end

      if dir
        # load from a different file than the normal one?
        # then save this log to the normal file too
        to_file()
      end

      return true
    else
      return false
    end
  end

  ########
  # accessor methods for table names and log data

  ###
  # returns: string, name of DB table with test data
  def testtable_name(testID)
    # no test ID given? use default
    unless testID
      testID = default_test_ID()
    end

    return @exp.instantiate("test_table_name", 
                            "exp_ID" => @exp.get("experiment_ID"),
                            "test_ID" => testID)
  end


  ###
  # returns: name of a split table (string)
  def splittable_name(splitID,  # string
                      dataset)  # string: train/test

    return "rosy_#{@exp.get("experiment_ID")}_split_#{dataset}_#{splitID}"
  end

  ### 
  # returns: test IDs for the current experiment (list of strings)
  def testIDs()
    return @log_obj.testIDs
  end

  ### 
  # returns: test IDs for the current experiment (list of strings)
  def splitIDs()
    return @log_obj.splitIDs
  end

  ###
  # get a runlog, make a new one if necessary.
  # If necessary, the table is extended by an additional column for this.
  # returns: a string, the column name for the classification run.
  def new_runlog(step,     # argrec/arglab/onestep
                 dataset,  # train/test
                 testID,   # string (testID) or nil
                 splitID)  # string (splitID) or nil

    table_name = proper_table_for_runlog(step, dataset, testID, splitID)
    loglist = get_runlogs(table_name)
    runlog = encode_setting_into_runlog(step,dataset)

    if (rl = existing_runlog_aux(loglist, runlog))
      # runlog already exists
      return rl.column
      
    else
      # runlog does not exist yet.
      # find the first free column
      existing_cols = loglist.select { |rl| rl.okay }.map { |rl| rl.column }
      @classif_columns.each { |colname, format| 

        unless existing_cols.include? colname
          # found an unused column name:
          # use it
          runlog.column = colname
          add_to_runlog(table_name, runlog)
          return colname
        end
      }

      # no free column found in the list of classifier columns
      # that is added to each table on construction.
      # So we have to extend the table.
      # First find out the complete list of used column names:
      # all table columns starting with @addcol_prefix
      used_classif_columns = Hash.new
      @database.list_column_names(table_name).each { |column_name|
        if column_name =~ /^#{@addcol_prefix}/
          used_classif_columns[column_name] = true
        end
      }
      # find the first unused column name in the DB table
      run_id = 0
      while used_classif_columns[classifcolumn_name(run_id)]
        run_id += 1
      end
      colname = classifcolumn_name(run_id)

      # add a column of this name to the table
      table = DBTable.new(@database, table_name,
                          "open",
                          "addcol_prefix" => @addcol_prefix)

      begin
        table.change_format_add_columns([[colname, "VARCHAR(20)"]])
      rescue MysqlError => e
        puts "Caught MySQL error at "+Time.now.to_s
        raise e
      end
      puts "Finished adding column at "+Time.now.to_s
      
      # now use that column
      runlog.column = colname
      add_to_runlog(table_name, runlog)
      return colname
    end    
  end

  ###
  # get an existing runlog
  # returns: if successful, a string, the column name for the classification run.
  #          else nil.
  def existing_runlog(step,     # argrec/arglab/onestep
                      dataset,  # train/test
                      testID,   # string (testID) or nil
                      splitID)  # string (splitID) or nil

    loglist = get_runlogs(proper_table_for_runlog(step, dataset, testID, splitID))
    if (rl = existing_runlog_aux(loglist, encode_setting_into_runlog(step,dataset)))
      # runlog found
      return rl.column
    else
      return nil
    end    
  end

  ###
  # confirm runlog:
  #  set "okay" to true
  # necessary for new runlogs, otherwise they count as nonexistent
  # fails silently if the runlog wasn't found
  def confirm_runlog(step,     # argrec/arglab/onestep
                     dataset,  # train/test
                     testID,   # string (testID) or nil
                     splitID,  # string (splitID) or nil
                     runID)    # string: run ID
    loglist = get_runlogs(proper_table_for_runlog(step, dataset, testID, splitID))
    rl = loglist.detect { |rl| 
      rl.column == runID
    }
    if rl
      rl.okay = true
    end
    to_file()
  end


  ###
  # delete one run from the runlog
  def delete_runlog(table_name, # string: name of DB table
                    column_name) # string: name of the run column
    loglist = get_runlogs(table_name)
    loglist.delete_if { |rl| rl.column == column_name }
    to_file()
  end

  ###
  # runlog_to_s:
  # concatenates the one_runlog_to_s results
  # for all tables of this experiment
  #
  # If all runlogs are empty, returns "none known"
  def runlog_to_s()
    hashes = runlog_to_s_list()

    # join text from hashes into a string, omit tables without runs
    string = ""
    hashes. each { |hash|
      unless hash["runlist"].empty?
        string << hash["header"]
        string << hash["runlist"].map { |colname, text| text }.join("\n\n")
        string << "\n\n"
      end
    }

    if string.empty?
      # no classifier runs at all up to now
      return "(none known)"
    else
      return string
    end
  end

  ###
  # runlog_to_s_list:
  # returns a list of hashes with keys "table_name", "header", "runlist"
  # where header is a string describing one of 
  # the DB tables of this experiment, 
  # and runlist is a list of pairs [ column_name, text],
  # where text describes the classification run in the column column_name
  def runlog_to_s_list()
    retv = Array.new
    
    # main table
    retv << one_runlog_to_s("train", nil, nil)

    # test tables
    testIDs().each { |testID|
      retv << one_runlog_to_s("test", testID, nil)
    }
    # split tables
    splitIDs().each { |splitID|
      ["train", "test"].each { |dataset|
        retv  << one_runlog_to_s(dataset, nil, splitID)
      }   
    }

    return retv
  end
  
  #######
  # create new training/test/split table
  def new_train_table()

    # remove old runlogs, if they exist
    del_runlogs(@maintable_name)

    # make table
    return DBTable.new(@database, @maintable_name,
 		       "new",
 		       "col_formats" => @feature_columns + @classif_columns,
 		       "index_cols" => @feature_info.get_index_columns(),
 		       "addcol_prefix" => @addcol_prefix)
  end

  ###
  def new_test_table(testID = "apply") # string: test ID

    # remove old runlogs, if they exist
    del_runlogs(testtable_name(testID))

    # remember test ID
    unless @log_obj.testIDs.include? testID
      @log_obj.testIDs << testID
      to_file()
    end

    # make table
    return DBTable.new(@database,
                       testtable_name(testID),
		       "new",
		       "col_formats" => @feature_columns + @classif_columns,
		       "index_cols" => @feature_info.get_index_columns(),
		       "addcol_prefix" => @addcol_prefix)

  end

  ###
  def new_split_table(splitID, # string: split ID
                      dataset, # string: train/test
                      split_index_colname) # string: name of index column for split tables

    # remove old runlogs, if they exist
    del_runlogs(splittable_name(splitID, dataset))

    # remember split ID
    unless @log_obj.splitIDs.include? splitID
      @log_obj.splitIDs << splitID
      to_file()
    end

    # determine the type of the index column
    maintable = existing_train_table()
    index_name_and_type = maintable.list_column_formats.assoc(maintable.index_name)
    if index_name_and_type
      split_index_type = index_name_and_type.last
    else
      $stderr.puts "WARNING: Could not determine type of maintable index column,"
      $stderr.puts "Using int as default"
      split_index_type = "INT"
    end

    # make table
    return DBTable.new(@database, 
                       splittable_name(splitID, dataset),
                       "new",
                       "col_formats" => @split_columns + [[split_index_colname, split_index_type]] + @classif_columns,
                       "index_cols" => [split_index_colname], 
                       "addcol_prefix" => @addcol_prefix)
  end


  #######
  # open existing training or test table
  def existing_train_table()
    return DBTable.new(@database, @maintable_name,
		       "open",
		       "col_names" => @feature_names,
		       "addcol_prefix" => @addcol_prefix)
  end

  ###
  def existing_test_table(testID = "apply")
    return DBTable.new(@database,
                       testtable_name(testID),
		       "open",
		       "col_names" => @feature_names,
		       "addcol_prefix" => @addcol_prefix)
  end

  ###
  def existing_split_table(splitID, # string: split ID
                           dataset, # string: train/test
                           split_index_colname)

    return DBTable.new(@database,
                       splittable_name(splitID, dataset),
                       "open", 
                       "col_names" => @split_columns.map { |name, type| name} + [split_index_colname],
                       "addcol_prefix" => @addcol_prefix)
  end

  ##################
  # table existence tests

  ###
  def train_table_exists?()
    return @database.list_tables().include?(@maintable_name)
  end

  ###
  def test_table_exists?(testID) # string
    return @database.list_tables().include?(testtable_name(testID))
  end

  ###
  def split_table_exists?(splitID,  # string
                          dataset)  # string: train/test
    return @database.list_tables().include?(splittable_name(splitID, dataset))
  end

  ##################3
  # remove tables

  ###
  def remove_train_table()
    if train_table_exists?
      del_runlogs(@maintable_name)
      remove_table(@maintable_name)
    end
  end

  ###
  def remove_test_table(testID) # string
    # remove ID from log
    @log_obj.testIDs.delete(testID)
    to_file()

    # remove DB table
    if test_table_exists?(testID)
      del_runlogs(testtable_name(testID))
      remove_table(testtable_name(testID))
    end
  end
      
  ###
  def remove_split_table(splitID, # string
                         dataset) # string: train/test
    # remove ID from log
    @log_obj.splitIDs.delete(splitID)
    to_file()

    # remove DB table
    if split_table_exists?(splitID, dataset)
      del_runlogs(splittable_name(splitID, dataset))
      remove_table(splittable_name(splitID, dataset))
    end
  end


  ###################################
  private

  ###
  # returns: string, name of DB column with classification result 
  def classifcolumn_name(id)
    return @addcol_prefix + "_" + id.to_s
  end

  ###
  # remove DB table
  # returns: nothing
  def remove_table(table_name)
    begin
      @database.drop_table(table_name)
    rescue
      $stderr.puts "Error: Removal of data table #{table_name} failed:"
      $stderr.puts $!
    end
  end

  ###
  # returns: string, name of pickle file
  def pickle_filename(dir)
    if dir
      # use externally defined directory
      dir = File.new_dir(dir)
    else
      # use my own directory
      dir = File.new_dir(@exp.instantiate("rosy_dir",
                                          "exp_ID" => @exp.get("experiment_ID")))
    end
    
    return dir + "ttt_data.pkl"
  end

  ########
  # access and remove runlogs for a given DB table

  ###
  # returns: an Array of RunLog objects
  def get_runlogs(table_name) # string: DB table name
    unless @log_obj.runlogs[table_name]
      @log_obj.runlogs[table_name] = Array.new
    end

    return @log_obj.runlogs[table_name]
  end

  ###
  # removes from @log_obj.runlogs the array of RunLog objects
  # for the given DB table.
  # Saves the changed @log_obj to file.
  def del_runlogs(table_name) # string: DB table name
    @log_obj.runlogs.delete(table_name)
    to_file()
  end

  ###
  # add a line to a runlog,
  # save log object to file
  def add_to_runlog(table_name, # string: DB table name
                    runlog)
    get_runlogs(table_name) << runlog
    to_file()
  end

  ###
  # constructs the appropriate DB table name for a given runlog request
  # returns: string, DB table name
  def proper_table_for_runlog(step,     # argrec/arglab/onestep
                              dataset,  # train/test
                              testID,   # test ID or nil
                              splitID)  # splitID or nil

    # sanity check: runlog for training data? this can only be the argrec step
    if dataset == "train" and step and step != "argrec"
      raise "Shouldn't be here: #{dataset} #{step}"
    end      

    if splitID
      # access runlogs of a split table
      return splittable_name(splitID, dataset)
    end

    case dataset
    when "train"
      return @maintable_name
    when "test"
      return testtable_name(testID)
    else
      raise "Shouldn't be here"
    end
  end

  ###
  # encode setting into runlog
  # collects information on step, learner, model features and xwise
  # and returns them in a RunLog object
  # leaves the column entry of the RunLog object nil
  def encode_setting_into_runlog(step,
                                 dataset)
    rl = RunLog.new(nil, nil, nil, nil, nil, false)

    # step: encode only if this is a classification run on test data
    unless dataset == "train"
      rl.step = step
    end

    # learner: concatenation of all learners named in the experiment file,
    # sorted alphabetically.
    # 
    # @exp.get_lf("classifier") returns: array of pairs [classifier_name, options[array]]
    rl.learner = @exp.get_lf("classifier").map { |classif_name, options| classif_name }.sort.join(" ")

    # model features: encode into a number
    rl.modelfeatures = encode_model_features(step)

    # xwise: read from experiment file
    rl.xwise = @exp.get("xwise_" + step)
    unless rl.xwise
      # default: read one frame at a time
      rl.xwise = "frame"
    end
  
    return rl
  end

  ###
  # auxiliary for "new runlog" and "existing runlog"
  # to avoid double computation
  #
  # get a list of RunLog objects, check against a given 
  # RunLog object
  #
  # returns: runlog object, if found in the given list, 
  #   i.e. if all entries except the column name match
  #   and okay == true
  #   else returns nil
  def existing_runlog_aux(runlogs,               # list of RunLog objects
                          runlog)                # RunLog object
    
    runlogs.each { |rl|
      if rl.step == runlog.step and
          rl.learner == runlog.learner and
          rl.modelfeatures == runlog.modelfeatures and
          rl.xwise == runlog.xwise and
          rl.okay

        return rl
      end
    }

    # no luck
    return nil
  end

  ############
  # model features: encode into a number, decode from number

  ###
  # returns: an integer, encoding of the model features
  def encode_model_features(step) # string: train/test
    # list model features as hash
    temp = @feature_info.get_model_features(step)
    model_features = Hash.new
    temp.each { |feature_name|
      model_features[feature_name] = true
    }

    num = 0
    @feature_names.sort.each_with_index { |feature_name, ix|
      if model_features[feature_name]
        # set the ix-th bit in num from the right
        num |= 2**ix
      end
    }

    return num
  end

  ###
  # returns: a list of strings, the model features
  def decode_model_features(num) # integer: result of encode_model_features

    model_features = Array.new
    @feature_names.sort.each_with_index { |feature_name, ix|
      if num[ix] == 1
        model_features << feature_name
      end
    }

    return model_features
  end

  ###
  # one_runlog_to_s:
  # returns a hash with keys "table_name", "header", "runlist"
  #  table_name is a string: the table name
  #  header is a string describing the table
  #  runlist is a list of pairs [column name, descr] (string*string)
  #  where column name is the classifier column name and descr describes
  #  one classification run on table_name
  #
  # If the loglist is empty for this table, descr is empty
  def one_runlog_to_s(dataset, # train/test
                      testID,  # test ID
                      splitID) # split ID or nil

    table_name = proper_table_for_runlog(nil, dataset, testID, splitID)
    loglist = get_runlogs(table_name)

    header = "Classification runs for the #{dataset} table "
    if splitID
      header << " of split '#{splitID}' "
    elsif dataset == "test" and testID
      header << "'#{testID}' "
    end
    if dataset == "train"
      header << "(applying argrec classifiers to training data) "
    end
    header << "of experiment '#{@exp.get("experiment_ID")}'\n\n"

    descr = Array.new
    loglist.each { |rl|
      unless rl.okay
        next
      end

      string = ""
      if dataset == "test"
        string << "Step #{rl.step} "
      end
      string << "Xwise: #{rl.xwise}    Learners: #{rl.learner}\n"
      string << "Model features:\n\t"
      count = 0
      decode_model_features(rl.modelfeatures).each { |feature_name|
        if count % 5 !=  0
          string << ", "
        end
	count += 1
        string << feature_name
	if count % 5 == 0
          string << "\n\t"
        end
      }
      descr << [rl.column, string]
    }

    return {
      "table_name" => table_name,
      "header" => header, 
      "runlist" => descr
    }
  end



end
