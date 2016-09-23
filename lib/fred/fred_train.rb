# FredTrain
# Katrin Erk April 05
#
# Frame disambiguation system: train classifiers

require "ruby_class_extensions" # ???

# Shalmaneser packages
require 'fred/fred_conventions' # !!
require 'ml/classifier'
require 'fred/targets'
require 'fred/fred_split_pkg'
require 'fred/fred_feature_access'
# require "fred/FredNumTrainingSenses"

require 'logging'
require 'fred/fred_error'

require_relative 'task'

module Shalmaneser
  module Fred
    class FredTrain < Task
      ###
      # new
      #
      # evaluate runtime options and announce the task
      # FredConfigData object
      # hash: runtime option name (string) => value(string)
      def initialize(exp_obj, options)
        @exp = exp_obj
        @split_id = options['--logID']

        # make an object that can list lemmas and their senses
        @lemmas_and_senses_obj = Targets.new(@exp, nil, "r")
        unless @lemmas_and_senses_obj.targets_okay
          # error during initialization
          raise FredError, "FredTrain: Error: Could not read list of known targets, bailing out."
        end

        ###
        # start objects for the different classifier types

        # get_lf returns: array of pairs [classifier_name, options[array]]
        #
        # @classifiers: list of pairs [Classifier object, classifier name(string)]
        @classifiers = @exp.get_lf("classifier").map do |classif_name, options|
          [Classifier.new(classif_name, options), classif_name]
        end

        # sanity check: we need at least one classifier
        # @todo AB: Move it to FredConfigData.
        if @classifiers.empty?
          raise "I need at least one classifier, please specify using exp. file option 'classifier'"
        end

        # get an object for listing senses of each lemma
        @lemmas_and_senses = Targets.new(@exp, nil, "r")
      end

      ###
      # compute
      #
      # do the training
      def compute
        # announce the task
        LOGGER.info "#{PROGRAM_NAME} experiment #{@exp.get('experiment_ID')}: Training classifiers"\
                    "#{' using split with ID: ' + @split_id.to_s if @split_id}."

        if @split_id
          # make split object and parameter hash to pass to it
          split_obj = FredSplitPkg.new(@exp)
        else
          split_obj = nil
        end

        classif_dir = ::Shalmaneser::Fred.fred_classifier_directory(@exp, @split_id)
        # iterate through instance files
        FredFeatureAccess.each_feature_file(@exp, "train") do |filename, values|
          # progress report
          LOGGER.debug "Training on #{values['lemma']}."


          # only one sense? then just assign that
          num_senses = determine_training_senses(values["lemma"], @exp,
                                                 @lemmas_and_senses,
                                                 @split_id).length

          if num_senses > 1
            # more than one sense: train
            # if we're splitting the data, do that now
            if split_obj
              tempfile = split_obj.apply_split(filename, values["lemma"], "train", @split_id)

              if tempfile.nil?
                # the training part of the split doesn't contain any data
                $stderr.puts "Skipping #{values["lemma"]}: no training data in split"
                next
              end

              filename = tempfile.path
            end

            @classifiers.each do |classifier, classifier_name|
              # where do we write the classifier?
              output_name = classif_dir + ::Shalmaneser::Fred.fred_classifier_filename(classifier_name,
                                                                                       values["lemma"],
                                                                                       values["sense"])
              LOGGER.info "#{PROGRAM_NAME}: Writing classifier #{output_name}."

              classifier.train(filename, output_name)
            end # each classifier

            if split_obj
              tempfile.close(true)
            end

          elsif num_senses == 1
          # only one sense: no need to write a training file
          else
            $stderr.puts "Error: no senses for lemma #{values["lemma"]}"
          end
        end # each feature file
      end
    end
  end
end
