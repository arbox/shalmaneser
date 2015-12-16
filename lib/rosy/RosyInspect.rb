# RosyInspect
# KE May 05
#
# One of the main task modules of Rosy:
# inspect global data and experiment-specific data of the system

# Rosy packages
# require "RosyConventions"
require 'db/select_table_and_columns'
require "rosy/RosySplit"
require "rosy/RosyTask"
require "rosy/RosyTrainingTestTable"
require "rosy/View"

# Frprep packages
# require 'configuration/prep_config_data'

class RosyInspect < RosyTask

  def initialize(exp,      # RosyConfigData object: experiment description
                 opts,     # hash: runtime argument option (string) -> value (string)
                 ttt_obj)  # RosyTrainingTestTable object

    ##
    # remember the experiment description

    @exp = exp
    @ttt_obj = ttt_obj

    ##
    # check runtime options

    @tasks = Array.new
    @test_id = nil

    opts.each do |opt,arg|
      case opt
      when "--tables", "--tablecont", "--runs", "--split"
        @tasks << [opt, arg]
      when "--testID"
        @test_id = arg
      else
        # this is an option that is okay but has already been read and used by rosy.rb
      end
    end

    ##
    # preprocessing information in the experiment file: doesn't seem to be needed,
    # disabling for now
#     ##
#     # add preprocessing information to the experiment file object
#     if @test_id
#       # use test data
#       preproc_parameter = "preproc_descr_file_test"
#     else
#       # use training data
#       preproc_parameter = "preproc_descr_file_train"
#     end
#     preproc_expname = @exp.get(preproc_parameter)
#     if not(preproc_expname)
#       $stderr.puts "Please set the name of the preprocessing exp. file name"
#       $stderr.puts "in the experiment file, parameter #{preproc_parameter}"
#       exit 1
#     elsif not(File.readable?(preproc_expname))
#       $stderr.puts "Error in the experiment file:"
#       $stderr.puts "Parameter #{preproc_parameter} has to be a readable file."
#       exit 1
#     end
#     preproc_exp = FrPrepConfigData.new(preproc_expname)
#     @exp.adjoin(preproc_exp)

    # announce the task
    $stderr.puts "---------"
    $stderr.puts "Rosy experiment #{@exp.get("experiment_ID")}: Inspecting data."
    $stderr.puts "---------"
  end

  #####
  # perform
  #
  # do each of the inspection tasks set as options
  def perform()
    @tasks.each { |opt, arg|
      case opt
      when "--tables"
        inspect_tables()
      when "--tablecont"
        inspect_tablecont(arg)
      when "--runs"
        inspect_runs()
      when "--split"
        inspect_split(arg)
      end
    }

    if @tasks.empty?
      inspect_experiment()
    end
  end

  ################################
  private

  # print to stdout:
  # name and column names of each table
  # in this database
  def inspect_tables()
    puts
    puts "-----------------------------------------------"
    puts "List of all tables in the database"
    puts "-----------------------------------------------"
    puts

    @ttt_obj.database.list_tables().each { | table_name|
      puts "Table " + table_name
      puts "\tColumns: "
      print "\t"
      count = 0
      @ttt_obj.database.list_column_formats(table_name).each { |column_name, column_format|
        count += 1
        print column_name, " (", column_format, ")\t"
        if count % 4 == 0
          print "\n\t"
        end
      }
      puts
      puts
    }
    puts
  end

  # print to stdout:
  # contents of both the training and the test table
  # up to line N (if N is given)
  # or contents of just the table with the given ID
  def inspect_tablecont(id_numlines)

    table_id = nil
    num_lines = nil

    if id_numlines
      if id_numlines.include? ":"
        # both table ID and number of lines given
        parts = id_numlines.split(":")
        if parts.length == 1
          # only table ID given after all
          table_id = parts.first
          num_lines = nil
        else
          # both table ID and number of lines
          # last part: number of lines. Rest: table ID
          # (re-join in case the table ID includes a ':')
          num_lines = parts.pop()
          table_id = parts.join(":")
        end
      elsif not(id_numlines.empty?)
        # only number of lines given
        num_lines = id_numlines
      end
    end

    # sanity check: existing table ID?
    if table_id and not(@ttt_obj.database.list_tables().include?(table_id))
      $stderr.puts "Error: I don't know a table with ID #{table_id}"
      return
    end

    if table_id
      # handle table with given table ID

      puts
      puts "-----------------------------------------------"
      puts "Experiment " + @exp.get("experiment_ID").to_s + " table "+ table_id
      puts "-----------------------------------------------"
      puts

      db_table = DBTable.new(@ttt_obj.database,
                             table_id,
                             "open",
                             "addcol_prefix" => @exp.get("classif_column_name"))

      inspect_tablecont_aux(db_table, num_lines)

    else

      # handle training data
      puts
      puts "-----------------------------------------------"
      puts "Experiment " + @exp.get("experiment_ID").to_s + " training data"
      puts "-----------------------------------------------"
      puts

      if @ttt_obj.train_table_exists?
        db_table = @ttt_obj.existing_train_table()
        inspect_tablecont_aux(db_table, num_lines)
      else
        $stderr.puts "(No main table.)"
      end

      # handle test data
      if @test_id

        puts
        puts "-----------------------------------------------"
        puts "Experiment " + @exp.get("experiment_ID").to_s + " test data (#{@test_id})"
        puts "-----------------------------------------------"
        puts

        if @ttt_obj.test_table_exists?(@test_id)
          db_table = @ttt_obj.existing_test_table(@test_id)
          inspect_tablecont_aux(db_table, num_lines)
        else
          $stderr.puts "(No test table #{@test_id}.)"
        end
      end
    end
  end

  # auxiliary method for inspect_tablecont:
  # print the actual lines
  def inspect_tablecont_aux(table_obj,  # DBTable object
                            num_lines)  # integer: number of lines to read

    # collect column names
    column_names = @ttt_obj.database.list_column_names(table_obj.table_name)

    # move "gold" column to the end
    column_names.delete("gold")
    column_names << "gold"

    # print column names
    print column_names.map { |n| "[" + n + "]" }.join(" ")
    puts
    puts

    # select rows to print
    view = DBView.new([SelectTableAndColumns.new(table_obj, column_names)],
                      [],        # no restrictions on rows to pick
                      @ttt_obj.database, # database access
                      "gold" => "gold",    # name of gold feature
                      "line_limit" => num_lines) # number of lines to read

    # and print them
    view.write_to_file($stdout)
    view.close()
  end

  # print to stdout: all classification runs for the current experiment ID
  def inspect_runs()
    puts @ttt_obj.runlog_to_s()
  end

  # print to stdout: train, test sentence ID for given split
  def inspect_split(splitID)

    puts
    puts "-----------------------------------------------"
    puts "Split " + splitID.to_s
    puts "-----------------------------------------------"
    puts

    ["train", "test"].each { |dataset|

      puts "Dataset " + dataset
      puts "==========="
      puts

      table = @ttt_obj.existing_split_table(splitID, dataset, RosySplit.split_index_colname())
      view = DBView.new([SelectTableAndColumns.new(table, "*")], [], @ttt_obj.database)
      index = 1
      view.each_array { |row|
        print row.join(","), "   "
        if index % 3 == 0
          puts
        end
        index += 1
      }
      puts
    }
  end

  def inspect_experiment()
    puts "------------------------------------"
    puts "Experiment #{@exp.get("experiment_ID").to_s}"
    puts "------------------------------------"
    puts

    # main table
    aux_tableinfo(@ttt_obj.maintable_name, "main table")

    # test tables
    @ttt_obj.testIDs.each { |testID|
      aux_tableinfo(@ttt_obj.testtable_name(testID), "test table #{testID}")
    }
    # split tables
    @ttt_obj.splitIDs.each { |splitID|
      aux_tableinfo(@ttt_obj.splittable_name(splitID, "train"), "split table (training data) #{splitID}")
      aux_tableinfo(@ttt_obj.splittable_name(splitID, "test"), "split table (test data) #{splitID}")
    }

    # features
    puts "-----------------------"
    puts "Features computed in this experiment:"
    puts "-----------------------"

    @ttt_obj.feature_names.sort.each_with_index { |feature_name, ix|
      if ix % 4 == 0
        puts
      end
      print feature_name, " "
    }
    puts
    puts


    # Runs
    puts "-----------------------"
    puts "Classifier runs for this experiment:"
    puts "-----------------------"
    puts
    puts @ttt_obj.runlog_to_s()
    puts
  end

  def aux_tableinfo(table_name,  # string: name of DB table
                    table_descr) # string: which table is it?

    puts "--------------------------"
    puts table_descr
    puts "--------------------------"

    puts "Name: #{table_name}"
    puts "Rows: #{@ttt_obj.database.num_rows(table_name)}"
    puts
  end

 end
