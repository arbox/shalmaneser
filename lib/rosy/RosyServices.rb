# RosyServices
# KE May 05
#
# One of the main task modules of Rosy:
# remove database tables and experiments,
# dump experiment to files and load from files

require "ruby_class_extensions"

# Rosy packages
require 'rosy/rosy_conventions'
require "rosy/RosyIterator"
require "rosy/RosySplit"
require "rosy/RosyTask"
require "rosy/RosyTrainingTestTable"
require "rosy/View"

# Frprep packages
require 'configuration/frappe_config_data'

###################################################
class RosyServices < RosyTask

  def initialize(exp,      # RosyConfigData object: experiment description
                 opts,     # hash: runtime argument option (string) -> value (string)
                 ttt_obj)  # RosyTrainingTestTable object

    ##
    # remember the experiment description

    @exp = exp
    @ttt_obj = ttt_obj

    ##
    # check runtime options

    @tasks = []
    # defaults:
    @step = "onestep"
    @splitID = nil
    @testID = Rosy.default_test_ID


    opts.each do |opt,arg|
      case opt
      when "--deltable", "--delexp", "--delruns", "--delsplit", "--deltables"
        @tasks << [opt, arg]
      when "--dump", "--load", "--writefeatures"
        @tasks << [opt, arg]
      when "--step"
        unless ["argrec", "arglab", "both", "onestep"].include? arg
          raise "Classification step must be one of: argrec, arglab, both, onestep. I got: " + arg.to_s
        end
        @step = arg

      when "--logID"
        @splitID = arg

      when "--testID"
        @testID = arg

      else
        # this is an option that is okay but has already been read and used by rosy.rb
      end
    end
    # announce the task
    $stderr.puts "---------"
    $stderr.puts "Rosy experiment #{@exp.get("experiment_ID")}: Services."
    $stderr.puts "---------"
  end

  #####
  # perform
  #
  # do each of the inspection tasks set as options
  def perform
    @tasks.each { |opt, arg|
      case opt
      when "--deltable"
        del_table(arg)
      when "--deltables"
        del_tables
      when "--delexp"
        del_experiment
      when "--delruns"
        del_runs
      when "--delsplit"
        del_split(arg)
      when "--dump"
        dump_experiment(arg)
      when "--load"
        load_experiment(arg)
      when "--writefeatures"
        write_features(arg)
      end
    }
  end

  ################################
  private

  #####
  # del_table
  #
  # remove one DB table specified by its name
  # The method verifies whether the table should be deleted.
  # If the user gives an answer starting in "y", the table is deleted.
  def del_table(table_name) # string: name of DB table
    # check if we have this table
    unless @ttt_obj.database.list_tables.include? table_name
      $stderr.puts "Cannot find DB table #{table_name}."
      return
    end

    # really delete?
    $stderr.print "Really delete DB table #{table_name}? [y/n] "
    answer = gets.chomp
    unless answer =~ /^y/
      return
    end

    begin
      @ttt_obj.database.drop_table(table_name)
    rescue
      $stderr.puts "Error: Removal of #{table_name} failed."
      return
    end

    # done.
    $stderr.puts "Deleted table #{table_name}."
  end

  ######
  # del_tables
  #
  # for all the tables in the database, present their name and size,
  # and ask if it should be deleted.
  # this is good for cleaning up!

  def del_tables
    @ttt_obj.database.list_tables.each { |table_name|

      STDERR.print "Delete table #{table_name} (num. rows #{@ttt_obj.database.num_rows(table_name)})? [y/n] "
      answer = gets.chomp

      if answer =~ /^y/
        deletion_worked = false
        begin
          @ttt_obj.database.drop_table(table_name)
          deletion_worked = true
        rescue
          deletion_worked = false
        end
        if deletion_worked
          STDERR.puts "Table #{name} removed."
        else
          $stderr.puts "Error: Removal of #{name} failed."
        end
      end
    }
  end

  #####
  # del_experiment
  #
  # remove the experiment described by the experiment file @exp
  # The method verifies whether the experiment should be deleted.
  # If the user gives an answer starting in "y", the experiment is deleted.
  def del_experiment
    data_dir = File.new_dir(@exp.instantiate("rosy_dir", "exp_ID" => @exp.get("experiment_ID")))

    # no data? then don't do anything
    if not(@ttt_obj.train_table_exists?) and
        @ttt_obj.testIDs.empty? and
        @ttt_obj.splitIDs.empty? and
        Dir[data_dir + "*"].empty?
      $stderr.puts "No data to delete for experiment #{@exp.get("experiment_ID")}."
      # we have just made the directory data_dir by calling @exp.new_dir
      # undo that
      %x{rmdir #{data_dir}}
      return
    end


    # really delete?
    $stderr.print "Really delete experiment #{@exp.get("experiment_ID")}? [y/n] "
    answer = gets.chomp
    unless answer =~ /^y/
      return
    end

    # remove main table
    @ttt_obj.remove_train_table

    # remove test tables
    @ttt_obj.testIDs.each { |testID|
      @ttt_obj.remove_test_table(testID)
    }


    # remove split tables
    @ttt_obj.splitIDs.each { |splitID|
      @ttt_obj.remove_split_table(splitID, "train")
      @ttt_obj.remove_split_table(splitID, "test")
    }

    # remove files
    %x{rm -rf #{data_dir}}

    # done.
    $stderr.puts "Deleted experiment #{@exp.get("experiment_ID")}."
  end

  ############
  # del_runs
  #
  # interactively remove runs from the current experiment
  def del_runs
    # iterate through all tables and runs
    @ttt_obj.runlog_to_s_list.each { |table_descr|
      unless table_descr["runlist"].empty?
        # print description of the table
        $stderr.puts table_descr["header"]

        table_descr["runlist"].each { |run_id, run_descr|
          $stderr.puts run_descr
          $stderr.puts "Delete this run? [y/n] "
          answer = gets.chomp
          if answer =~ /^[yY]/
            @ttt_obj.delete_runlog(table_descr["table_name"], run_id)
          end
        }
      end
    }
  end

  ##############
  # del_split
  #
  # remove the split with the given ID
  # from the current experiment:
  # delete split tables, remove from list of test and split tables
  def del_split(splitID)
    # does the split exist?
    unless @ttt_obj.splitIDs.include? splitID
      $stderr.puts "del_split:"
      $stderr.puts "Sorry, I don't have a split with ID #{splitID} in experiment #{exp.get("experiment_ID")}."
      return
    end

    # really delete?
    $stderr.print "Really delete split #{splitID} of experiment #{@exp.get("experiment_ID")}? [y/n] "
    answer = gets.chomp
    unless answer =~ /^y/
      return
    end

    # remove split tables
    @ttt_obj.remove_split_table(splitID, "train")
    @ttt_obj.remove_split_table(splitID, "test")

    # remove classifiers for split
    ["argrec", "arglab", "onestep"].each { |step|
      classif_dir = Rosy::classifier_directory_name(@exp,step, splitID)
      %x{rm -rf #{classif_dir}}
    }
  end

  ##############
  # write features to files:
  # use
  #  @step, @testID, @splitID to determine feature set to write
  def write_features(directory) # string: directory to write to, may be nil

    ###
    # prepare directory to write to
    if directory != ""
      # the user has given a directory.
      # make sure it ends in /
      dir = File.new_dir(directory)
    else
      # use the default directory: <rosy_dir>/tables
      dir = File.new_dir(@exp.instantiate("rosy_dir",
                                          "exp_ID" => @exp.get("experiment_ID")),
                         "your_feature_files")
    end
    $stderr.puts "Writing feature files to directory " + dir

    ##
    # check: if this is about a split, do we have it?
    if @splitID
      unless @ttt_obj.splitIDs.include?(@splitID)
        $stderr.puts "Sorry, I have no data for split ID #{@splitID}."
        exit 1
      end
    end

    ##
    # inform the user on what we are writing
    if @splitID
      $stderr.puts "Writing data according to split '#{@splitID}'"
    elsif @testID
      # do we have this test set? else write only training set
      if @ttt_obj.testIDs.include?(@testID)
        $stderr.puts "Writing training data, and test data with ID '#{@testID}'"
      else
        $stderr.puts "Warning: no data for test ID '#{@testID}', writing only training data."
        @testID = nil
      end
    end

    $stderr.puts "Writing data for classification step '#{@step}'."
    $stderr.puts

    ##
    # write training data
    $stderr.puts "Writing training sets"
    iterator = RosyIterator.new(@ttt_obj, @exp, "train",
                                "step" => @step,
                                "splitID" => @splitID,
                                "prune" => true)

    # get the list of relevant features,
    # remove the features that describe the unit by which we train,
    # since they are going to be constant throughout the training file
    features = @ttt_obj.feature_info.get_model_features(@step) -
      iterator.get_xwise_column_names

    # but add the gold feature
    unless features.include? "gold"
      features << "gold"
    end


    write_features_aux(dir, "training", @step, iterator, features)

    ##
    # write test data
    if @testID
      $stderr.puts "Writing test sets"
      filename = dir + "test.data"
      iterator = RosyIterator.new(@ttt_obj, @exp, "test",
                                  "step" => @step,
                                  "testID" => @testID,
                                  "splitID" => @splitID,
                                  "prune" => true)
      write_features_aux(dir, "test", @step, iterator, features)
    end
  end

  ########
  # write_features_aux: actually do the writing
  def write_features_aux(dir,      # string: directory to write to
                         dataset,  # string: training or test
                         step,     # string: argrec, arglab, onestep
                         iterator, # RosyIterator tuned to what we're writing
                         features) # array:string: list of features to include in views

    # proceed one group at a time
    iterator.each_group { |group_descr_hash, group|
      # get data for this group
      view = iterator.get_a_view_for_current_group(features)

      #filename: e.g. directory/training.Statement.data
      filename = dir + dataset + "." +
        step + "." +
        group.gsub(/\s/, "_") + ".data"

      begin
        file = File.new(filename, "w")
      rescue
        $stderr.puts "Error: Could not write to file #{filename}, exiting."
        exit 1
      end

      view.each_instance_s { |instance_string|
        # change punctuation to _PUNCT_
        # and change empty space to _
        # because otherwise some classifiers may spit
        file.puts Rosy::prepare_output_for_classifiers(instance_string)
      }
      file.close
      view.close
    }
  end

  ##############3
  # dump_experiment
  #
  # dump to file:
  # - main table. filename: main
  # - test tables. filename: test.<testID>
  # - split tables. filenames: split.train.<ID>, split.test.<ID>
  # of the experiment given in @exp.
  #
  # Each table is dumped in a separate file:
  # The first line describes column names,
  # each following line is one row of the DB.
  #
  # Files are written to <rosy_dir>/tables
  def dump_experiment(directory) #string: directory to write to, may be nil
    ###
    # prepare:

    # directory to write to
    if directory != ""
      # the user has given a directory.
      # make sure it ends in /
      dir = File.new_dir(directory)
    else
      # use the default directory: <rosy_dir>/tables
      dir = File.new_dir(@exp.instantiate("rosy_dir",
                                          "exp_ID" => @exp.get("experiment_ID")),
                         "tables")
    end
    $stderr.puts "Writing experiment data to directory " + dir

    ###
    # dump main table

    $stderr.puts "Dumping main table"
    filename = dir + "main"
    begin
      file = File.new(filename, "w")
    rescue
      $stderr.puts "Sorry, couldn't write to #{filename}"
      return
    end

    if @ttt_obj.train_table_exists?
      iterator = RosyIterator.new(@ttt_obj, @exp, "train", "xwise" => "frame")
      table_obj = @ttt_obj.existing_train_table
      aux_dump(iterator, file, table_obj)
    end

    ###
    # dump test tables

    unless @ttt_obj.testIDs.empty?
      $stderr.print "Dumping test tables: "
    end
    @ttt_obj.testIDs.each { |testID|

      filename = dir + "test." + testID
      $stderr.print filename, " "
      begin
        file = File.new(filename, "w")
      rescue
        $stderr.puts "Sorry, couldn't write to #{filename}"
        return
      end

      if @ttt_obj.test_table_exists?(testID)
        iterator = RosyIterator.new(@ttt_obj, @exp, "test", "testID" => testID, "xwise" => "frame")
        table_obj = @ttt_obj.existing_test_table(testID)
        aux_dump(iterator, file, table_obj)
      end
    }
    unless @ttt_obj.testIDs.empty?
      $stderr.puts
    end

    # dump split tables
    unless @ttt_obj.splitIDs.empty?
      $stderr.print "Dumping split tables: "
    end
    @ttt_obj.splitIDs.each { |splitID|
      ["train", "test"].each { |dataset|

        filename = dir + "split." + dataset + "." + splitID
        $stderr.print filename, " "
        begin
          file = File.new(filename, "w")
        rescue
          $stderr.puts "Sorry, couldn't write to #{filename}"
          return
        end

        if @ttt_obj.split_table_exists?(splitID, dataset)
          iterator = RosyIterator.new(@ttt_obj, @exp, dataset, "splitID" => splitID, "xwise" => "frame")
          table_obj = @ttt_obj.existing_split_table(splitID, dataset, RosySplit.split_index_colname)
          aux_dump(iterator, file, table_obj)
        end
      }
    }
    unless @ttt_obj.splitIDs.empty?
      $stderr.puts
    end

    ###
    # dump classification run logs
    @ttt_obj.to_file(dir)
  end

  ################3
  # aux_dump
  #
  # auxiliary method for dump_experiment()
  def aux_dump(iterator, # RosyIterator object, refers to table to write
               file, # stream: write to this file
               table_obj) # DB table to be written

    # write all columns except the autoincrement index
    # columns_to_write: array:string*string column name, column SQL type
    columns_to_write = []
    @ttt_obj.database.list_column_formats(table_obj.table_name).each { |column_name, column_type|
      unless column_name == table_obj.index_name
        # check: when loading we make assumptions on the field types that can happen.
        # check here that we don't get any unexpected field types
        case column_type
        when /^varchar\d*\(\d+\)$/i, /^char\d*\(\d+\)$/i, /^tinyint(\(\d+\))*$/i, /^int/i
        else
          $stderr.puts "Problem with SQL type #{column_type} of column #{column_name}:"
          $stderr.puts "Won't be able to handle it when loading."
        end
        columns_to_write << [column_name, column_type]
      end
    }
    columns_as_array = columns_to_write.map { |name, type| name}

    # write column names and types
    file.puts columns_to_write.map { |name, type| name }.join(",")
    file.puts columns_to_write.map { |name, type| type }.join(",")

    # access groups and write data

    iterator.each_group { |hash, framename|
      view = iterator.get_a_view_for_current_group(columns_as_array)

      # write instances
      view.each_hash { |instance|
        file.puts columns_to_write.map { |name, type|
          # get column entries in order of column names
          instance[name]
        }.map { |entry|
          # remove commas
          entry.to_s.gsub(/,/, "COMMA")
        }.join(",")
      }
      view.close
    }
  end

  ##############3
  # load_experiment
  #
  # load from file:
  # - main table
  # - test tables
  # - split tables
  #
  # Filenames: see dump_experiment()
  #
  # Data is loaded into the current experiment,
  # previous experiment data is removed
  #
  # Each table is loaded from a separate file:
  # The first line describes column names,
  # each following line is one row of the DB.
  def load_experiment(directory) # string: directory to read from, may be nil

    ###
    # ask whether this is what the user intended
    $stderr.puts "Load experiment data from files into the current experiment:"
    $stderr.puts "This will overwrite existing data of experiment #{@exp.get("experiment_ID")}."
    $stderr.print "Proceed? [y/n] "
    answer = gets.chomp
    unless answer =~ /^y/
      return
    end

    ##
    # adjoin preprocessing experiment file to find out about the language of the data
    # for this it is irrelevant whether we take the training or test
    # preprocessing experiment file. Take the training file.
    preproc_expname = @exp.get("preproc_descr_file_train")
    if not(preproc_expname)
      $stderr.puts "Please set the name of the preprocessing exp. file name"
      $stderr.puts "in the experiment file, parameter preproc_descr_file_train."
      exit 1
    elsif not(File.readable?(preproc_expname))
      $stderr.puts "Error in the experiment file:"
      $stderr.puts "Parameter preproc_descr_file_train has to be a readable file."
      exit 1
    end
    # @note Remove this dependency.
    preproc_exp = ::Shalmaneser::Configuration::FrappeConfigData.new(preproc_expname)
    @exp.adjoin(preproc_exp)

    ###
    # read the data where?
    if directory != ""
      # the user has given a directory
      # make sure it exists
      dir = File.existing_dir(directory)
    else
      # default: <rosy_dir>/tables
      dir = File.existing_dir(@exp.instantiate("rosy_dir",
                                               "exp_ID" => @exp.get("experiment_ID")),
                              "tables")
    end
    $stderr.puts "Reading experiment data from directory " + dir

    ###
    # read tables
    Dir.foreach(dir) { |filename|
      case filename
      when "main"
        # read main file
        $stderr.puts "Writing main DB table"

        file = File.new(dir + filename)
        col_names, col_types = aux_read_colnames(file, @ttt_obj.feature_names)

        # start new main table, removing the old
        table_obj = @ttt_obj.new_train_table()
        # write file contents to the DB table
        aux_transfer_to_table(file, table_obj, col_names, col_types)

      when /^test\.(.+)$/
        # read test file
        testID = $1
        $stderr.puts "Writing test DB table with ID #{testID}"

        file = File.new(dir + filename)
        col_names, col_types = aux_read_colnames(file, @ttt_obj.feature_names)

        # start new test table, removing the old
        table_obj = @ttt_obj.new_test_table(testID)
        # write file contents to the DB table
        aux_transfer_to_table(file, table_obj, col_names, col_types)

      when /^split\.(train|test)\.(.+)$/
        dataset = $1
        splitID = $2
        $stderr.puts "Writing split #{dataset} DB table with ID #{splitID}"

        file = File.new(dir + filename)
        col_names, col_types = aux_read_colnames(file, nil)
        table_obj = @ttt_obj.new_split_table(splitID, dataset, RosySplit.split_index_colname)
        # write file contents to the DB table
        aux_transfer_to_table(file, table_obj, col_names, col_types)

      else
        # not a filename we recognize
        # don't do anything with it
      end
    }

    success = @ttt_obj.from_file(dir)
    unless success
      $stderr.puts "Could not read previous classification runs, assume empty."
    end
  end

  ##
  # aux_read_colnames
  #
  # auxiliary method for load_experiment
  #
  # read column names from dumped DB table file,
  # compare to given set of column names,
  # complain if they don't match
  #
  # returns: array*array, first array(strings): column names
  #   second array(strings): column SQL types
  def aux_read_colnames(file, # stream: file to read DB table info from
                        exp_colnames) # array:string, column names defined in the experiment file
    colnames = aux_read_columns(file)
    # sanity check: features here the same as in the experiment file?
    if exp_colnames
      feature_colnames = colnames.select { |c| c !~ /^#{@exp.get("classif_column_name")}/ }
      unless feature_colnames.sort == exp_colnames.sort
        raise "Feature name mismatch!\nIn the experiment file, you have specified:\n" +
            exp_colnames.sort.join(",") +
            "\nIn the table I'm reading from file I got:\n" +
            feature_colnames.sort.join(",")
      end
    else
      # no check of column name match requested
    end
    coltypes = aux_read_columns(file)
    return [colnames, coltypes]
  end


  ##
  # aux_transfer_columns
  #
  # auxiliary method for load_experiment:
  # read a line from file, split it at commas
  #   to arrive at the contents
  def aux_read_columns(file) # stream: file
    line = file.gets
    if line.nil?
      return nil
    end
    line.chomp!
    return line.split(",")
  end

  ###
  # aux_transfer_to_table
  #
  # auxiliary method for load_experiment:
  # read columns from file,
  # write to table, omitting nil values
  def aux_transfer_to_table(file, # stream: read from this file
                            table_obj, # DBTable object: write to this table
                            col_names, # array:string: these are the column names
                            col_types) # array:string: SQL column types


    # sp workaround Tue Aug 23
    # table may have too few classification columns since it has been created with only
    # the standard set of classification columns. Add more if needed

    col_names.each {|col_name|
      if !(table_obj.list_column_names.include? col_name) and col_name =~ /^#{@exp.get("classif_column_name")}/
        table_obj.change_format_add_columns([[col_name, "VARCHAR(20)"]])
      end
    }

    # write file contents to the DB table
    names_and_values = []
    while row =  aux_read_columns(file)
      names_and_values.clear
      col_names.each_with_index { |name, ix|
        unless row[ix].nil?
          if col_types[ix] =~ /^(TINYINT|tinyint)/
            # integer value: map!
            names_and_values << [name, row[ix].to_i]
          else
            # string value: leave as is
            names_and_values << [name, row[ix]]
          end
        end
      }
      table_obj.insert_row(names_and_values)
    end
  end
 end
