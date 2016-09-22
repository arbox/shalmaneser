require 'monkey_patching/file'

module Shalmaneser
  module Rosy
    ##
    # RosyTask
    # KE, SP April 05
    #
    # this is the abstract class that describes the interface for
    # the task classes of Rosy.
    #
    # all task classes should have a perform() method that actually
    # performs the task.
    # @abstract
    # @todo AB: [2016-09-20 Tue]
    #       Do we actually need this class?
    class Task
      # @abstract
      def initialize
        raise NotImplementedError
      end
      # @abstract
      def perform
        raise NotImplementedError
      end

      private

      # transforming feature output to a format that classifiers can handle
      # @note Moved from RosyConventions.
      def prepare_output_for_classifiers(string)
        # change punctuation to _PUNCT_
        # and change empty space to _
        # because otherwise some classifiers may spit
        string.gsub(/[.":';`]/, "_PUNCT_").gsub(/\s/, "_")
      end

      ###
      # classifier directory:
      #  either user-given classifier_dir or our own default classifier directory,
      #  then argrec/arglab/onestep, plus the splitID, if there is one
      # @note Need the extended File class.
      # @note Used only under Rosy.
      # @note Moved from RosyConventions.
      # @param exp [RosyConfigData]
      # @param step [String] One of argrec, arglab, or onestep.
      # @param split_id [String] A string or NIL.
      def classifier_directory_name(exp, step, split_id)
        base_dir = if exp.get("classifier_dir")
                     File.new_dir(exp.get("classifier_dir"))
                   else
                     File.new_dir(exp.instantiate("rosy_dir", {"exp_ID" => exp.get("experiment_ID")}))
                   end

        classif_base_dir = File.new_dir(base_dir, "classif_dir")

        if split_id
          return File.new_dir(classif_base_dir, step + "." + split_id.to_s)
        else
          return File.new_dir(classif_base_dir, step)
        end
      end
    end
  end
end
