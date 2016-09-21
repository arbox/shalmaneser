# AB: 2011-11-14
# Initial import done, need to reimplement the whole interface.

require 'monkey_patching/file'
require 'db/db_interface'
require_relative 'tasks'
require 'logging'
require_relative 'rosy_error'
require_relative 'training_test_table'

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
        database = DB::DBInterface.get_db_interface(@exp, rosy_dir, "features")

        table_obj = TrainingTestTable.new(@exp, database)

        ##
        # start the actual processing,
        # according to given arguments

        # initialize task object
        task = case @task
               when "featurize"
                 FeaturizationTask.new(@exp, @opts, table_obj)
               when "split"
                 SplittingTask.new(@exp, @opts, table_obj)
               when "train"
                 TrainingTask.new(@exp, @opts, table_obj)
               when "test"
                 TestingTask.new(@exp, @opts, table_obj)
               when "eval"
                 EvaluationTask.new(@exp, @opts, table_obj)
               when "inspect"
                 InspectionTask.new(@exp, @opts, table_obj)
               when "services"
                 ServiceTask.new(@exp, @opts, table_obj)
               else
                 raise "Shouldn't be here"
               end

        # execute task
        begin
          task.perform
        rescue => e
          raise RosyError.new 'Rosy is doing bad!', e
        ensure
          database.close
        end

        LOGGER.info "#{PROGRAM_NAME} finished performing the task: #{task}!"
      end
    end # class Rosy
  end # module Rosy
end
