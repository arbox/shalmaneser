# FredTrain
# Katrin Erk April 05
#
# Frame disambiguation system: train classifiers

require "ruby_class_extensions"


# Shalmaneser packages
require 'fred/FredConventions' # !
require 'ml/classifier'
require "fred/FredDetermineTargets"
require 'fred/fred_split_pkg'
require "fred/FredFeatures"
# require "fred/FredNumTrainingSenses"

module Shalmaneser
module Fred
class FredTrain

  ###
  # new
  #
  # evaluate runtime options and announce the task
  def initialize(exp_obj, # FredConfigData object
                 options) # hash: runtime option name (string) => value(string)

    @exp = exp_obj

    # evaluate runtime options
    @split_id = nil

    options.each_pair { |opt, arg|
      case opt
      when "--logID"
        @split_id = arg

      else
        # case of unknown arguments has been dealt with by fred.rb
      end
    }

    # announce the task
    $stderr.puts "---------"
    $stderr.print "Fred experiment #{@exp.get("experiment_ID")}: Training classifiers"
    if @split_id
      $stderr.puts " using split with ID #{@split_id}"
    else
      $stderr.puts
    end
    $stderr.puts "---------"

    # make an object that can list lemmas and their senses
    @lemmas_and_senses_obj = Targets.new(@exp, nil, "r")
    unless @lemmas_and_senses_obj.targets_okay
      # error during initialization
      $stderr.puts "FredTrain: Error: Could not read list of known targets, bailing out."
      exit 1
    end

    ###
    # start objects for the different classifier types

    # get_lf returns: array of pairs [classifier_name, options[array]]
    #
    # @classifiers: list of pairs [Classifier object, classifier name(string)]
    @classifiers = @exp.get_lf("classifier").map { |classif_name, options|
      [Classifier.new(classif_name, options), classif_name]
    }
    # sanity check: we need at least one classifier
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
    if @split_id
      # make split object and parameter hash to pass to it
      split_obj = FredSplitPkg.new(@exp)
    else
      split_obj = nil
    end

    classif_dir = ::Shalmaneser::Fred.fred_classifier_directory(@exp, @split_id)
    # iterate through instance files
    FredFeatureAccess.each_feature_file(@exp, "train") { |filename, values|
      # progress report
      if @exp.get("verbose")
        $stderr.puts "Training on " + values["lemma"]
      end

      # only one sense? then just assign that
      num_senses = ::Shalmaneser::Fred.determine_training_senses(values["lemma"], @exp,
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

        @classifiers.each { |classifier, classifier_name|
          # where do we write the classifier?
          output_name = classif_dir + ::Shalmaneser::Fred.fred_classifier_filename(classifier_name,
                                                               values["lemma"],
                                                               values["sense"])
          # HIER
           $stderr.puts "FRED: Writing classifier #{output_name}"

          classifier.train(filename, output_name)
        } # each classifier

        if split_obj
          tempfile.close(true)
        end

      elsif num_senses  == 1
        # only one sense: no need to write a training file
      else
        $stderr.puts "Error: no senses for lemma #{values["lemma"]}"
      end

    } # each feature file
  end
end
end
end
