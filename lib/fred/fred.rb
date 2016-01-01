# AB: 2011-11-13
# Initial import done, need to reimplement the whole interface.
require 'fred/FredFeaturize'
require 'fred/FredSplit'
require 'fred/FredTrain'
require 'fred/FredTest'
require 'fred/FredEval'

require 'logging'
require 'definitions'

module Shalmaneser
  module Fred
    class Fred
      def initialize(options)
        @exp, @opts = options
        @task = @opts['--task']
      end

      ##
      # now perform the given task
      def assign
        # initialize task object
        task = case @task
               when "featurize"
                 FredFeaturize.new(@exp, @opts)
               when "refeaturize"
                 FredFeaturize.new(@exp, @opts, "refeaturize" => true)
               when "split"
                 FredSplit.new(@exp, @opts)
               when "train"
                 FredTrain.new(@exp, @opts)
               when "test"
                 FredTest.new(@exp, @opts)
               when "eval"
                 FredEval.new(@exp, @opts)
               else
                 raise ArgumentError, "Wrong taks for #{PROGRAM_NAME}: #{@task}!"
                 # @todo AB: this <else> condition should be unpossible
                 #     do in OptionParser
               end

        task.compute
        LOGGER.info "#{PROGRAM_NAME} finished performing the task: #{task}!"
      end
    end # class Fred
  end # module Fred
end
