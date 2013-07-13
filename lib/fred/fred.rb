# AB: 2011-11-13
# Initial import done, need to reimplement the whole interface.
require 'fred/FredFeaturize'
require 'fred/FredSplit'
require 'fred/FredTrain'
require 'fred/FredTest'
require 'fred/FredEval'

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
      case @task
      when "featurize"
        task_obj = FredFeaturize.new(@exp, @opts)
      when "refeaturize"
        task_obj = FredFeaturize.new(@exp, @opts, "refeaturize" => true)
      when "split"
        task_obj = FredSplit.new(@exp, @opts)
      when "train"
        task_obj = FredTrain.new(@exp, @opts)
      when "test"
        task_obj = FredTest.new(@exp, @opts)
      when "eval"
        task_obj = FredEval.new(@exp, @opts)
      else
        raise "Shouldn't be here"
      end
      
      task_obj.compute
      
      $stderr.puts "Fred: Done."
      
    end
  end # class Fred
end # module Fred
