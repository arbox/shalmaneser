# RosyEval
# KE May 05
#
# Evaluation for Rosy:
# Precision, Recall, F-score
# Output to evaluation file,
# plus optional output of evaluation log file.
#
# Builds on the general Salsa Eval package

# Salsa packages
require 'eval'
require "ruby_class_extensions"
require 'definitions'
# Rosy packages
require_relative 'iterator'
require_relative 'splitting_task'
require_relative 'task'
require_relative 'pruning'

require 'configuration/frappe_config_data'

require_relative 'rosy_eval'

module Shalmaneser
  module Rosy
    ###########################################################
    # This is the class to be called from rosy.rb
    ###########################################################
    class EvaluationTask < Task
      # @todo Correct this description.
      # @param exp       # RosyConfigData object: experiment description
      # @param opts       # @param exp       # RosyConfigData object: experiment descript
      # @param ttt_obj # RosyTrainingTestTable object
      def initialize(exp, opts, ttt_obj)
        @exp = exp
        @ttt_obj = ttt_obj

        ##
        # check runtime options
        @step = "both"
        @splitID = nil
        @testID = DEFAULT_TEST_ID

        opts.each do |opt, arg|
          case opt
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
      end

      def perform
        dont_adjoin_frprep_exp = nil
        original_step = @step

        if ["both", "argrec", "onestep"].include? original_step and
          Pruning.prune?(@exp)
          # evaluate pruning
          $stderr.puts "Rosy evaluating pruning"
          @step = "prune"
          perform_aux
          dont_adjoin_frprep_exp = "dont_adjoin_frprep_exp"
        end

        if original_step == "both"
          # both? then do first argrec, then arglab
          $stderr.puts "Rosy evaluating step argrec"
          @step = "argrec"
          perform_aux(dont_adjoin_frprep_exp)


          $stderr.puts "Rosy evaluating step arglab"
          @step = "arglab"
          perform_aux("dont_adjoin_frprep_exp")

        # KE Jan 30, 2006: evaluation "all" deactivated until we've
        # figured out how to evaluate accuracy for the NONE class
        #      $stderr.puts "Rosy overall evaluation"
        #      @step = "all"
        #      perform_aux("dont_adjoin_frprep_exp")

        else
          # not both? then just do one
          @step = original_step
          perform_aux(dont_adjoin_frprep_exp)
        end
      end

      ###############
      private

      # perform_aux: do the actual work of the perform() method
      # moved here because of the possibility of having @step=="both",
      # which makes it necessary to perform two eval steps one after the other
      def perform_aux(dont_adjoin_frprep_exp = nil)  # string passed on to RosyEval initialize method
        # construct names for evaluation output file
        # and evaluation log file (which classifies each instances as correct/incorrect/unassigned)
        if @splitID
          outfilename_id = "split" + @splitID
        else
          outfilename_id = "test" + @testID
        end
        @outfilename = File.new_filename(@exp.instantiate("rosy_dir",
                                                          "exp_ID" => @exp.get("experiment_ID")),
                                         @exp.instantiate("eval_file",
                                                          "exp_ID" => @exp.get("experiment_ID"),
                                                          "test_ID" => outfilename_id,
                                                          "step" => @step))

        if @exp.get("print_eval_log")
          @logfilename = File.new_filename(@exp.instantiate("rosy_dir",
                                                            "exp_ID" => @exp.get("experiment_ID")),
                                           @exp.instantiate("log_file",
                                                            "exp_ID" => @exp.get("experiment_ID"),
                                                            "test_ID" => outfilename_id,
                                                            "step" => @step))
        else
          @logfilename = nil
        end
        @eval_obj = RosyEval.new(@exp, @ttt_obj, @step, @splitID, @testID,
                                 @outfilename, @logfilename,
                                 dont_adjoin_frprep_exp)
        @eval_obj.compute
      end
    end
  end
end
