# AB: 2011-11-14
# Initial import done, need to reimplement the whole interface.

require 'db/db_interface'
require 'rosy/RosyFeaturize'
require 'rosy/RosyTest'
require 'rosy/RosyTrain'
require 'rosy/RosyInspect'
require 'rosy/RosyEval'
require 'rosy/RosyServices'

module Shalmaneser
module Rosy
  class Rosy

    def initialize(options)
      @exp, @opts = options
      @task = @opts['--task']
    end

    def assign

      # make rosy directory pattern:
      # main rosy directory name (data_dir) plus subdirectory
      # named after the experiment ID
      rosy_dir_pattern = File.new_dir(@exp.get("data_dir")) + "<exp_ID>/"
      @exp.set_entry("rosy_dir", rosy_dir_pattern)

      ##
      # open database

      rosy_dir = File.new_dir(@exp.instantiate("rosy_dir",
                                              "exp_ID" => @exp.get("experiment_ID")))
      database = DBInterface.get_db_interface(@exp, rosy_dir, "features")

      table_obj = RosyTrainingTestTable.new(@exp, database)

      ##
      # start the actual processing,
      # according to given arguments

      # initialize task object
      #begin
      case @task
      when "featurize"
        task_obj = RosyFeaturize.new(@exp, @opts, table_obj)
      when "split"
        task_obj = RosySplit.new(@exp, @opts, table_obj)
      when "train"
        task_obj = RosyTrain.new(@exp, @opts, table_obj)
      when "test"
        task_obj = RosyTest.new(@exp, @opts, table_obj)
      when "eval"
        task_obj = RosyEvalTask.new(@exp, @opts, table_obj)
      when "inspect"
        task_obj = RosyInspect.new(@exp, @opts, table_obj)
      when "services"
        task_obj = RosyServices.new(@exp, @opts, table_obj)
      else
        raise "Shouldn't be here"
      end

      # execute task
      begin
        task_obj.perform
      rescue
        raise
        # puts e.backtrace
        # fail "Error during task execution: #{e.class}=>#{e.message}"
      ensure
        database.close
      end
      $stderr.puts "Rosy: done."
    end

  end # class Rosy
end # module Rosy
end
