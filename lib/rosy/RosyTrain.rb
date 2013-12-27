# RosyTrain
# KE May 05
#
# One of the main task modules of Rosy:
# train classifiers

# Ruby standard library
require "tempfile"


# Rosy packages
require "rosy/RosyTask"
require "rosy/RosyTest"
require "common/RosyConventions"
require "rosy/RosyIterator"
require "rosy/RosyTrainingTestTable"
require "rosy/RosyPruning"
require "common/ML"

# Frprep packages
require "common/prep_config_data"

class RosyTrain < RosyTask

  def initialize(exp,      # RosyConfigData object: experiment description
		 opts,     # hash: runtime argument option (string) -> value (string)
		 ttt_obj)  # RosyTrainingTestTable object

    #####
    # In enduser mode, this whole task is unavailable
    in_enduser_mode_unavailable()

    ##
    # remember the experiment description

    @exp = exp
    @ttt_obj = ttt_obj

    ##
    # check runtime options

    # defaults:
    @step = "both"
    @splitID = nil

    opts.each { |opt,arg|
      case opt
      when "--step"
	unless ["argrec", "arglab", "onestep", "both"].include? arg
	  raise "Classification step must be one of: argrec, arglab, both, onestep. I got: " + arg.to_s
	end
	@step = arg
      when "--logID"
        @splitID = arg
      else
	# this is an option that is okay but has already been read and used by rosy.rb
      end	
    }

    ##
    # check: if this is about a split, do we have it?
    if @splitID
      unless @ttt_obj.splitIDs().include?(@splitID)
        $stderr.puts "Sorry, I have no data for split ID #{@splitID}."
        exit 0
      end
    end

    ##
    # add preprocessing information to the experiment file object
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
    preproc_exp = FrPrepConfigData.new(preproc_expname)
    @exp.adjoin(preproc_exp)
    

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

    # announce the task
    $stderr.puts "---------"
    $stderr.print "Rosy experiment #{@exp.get("experiment_ID")}: Training "
    if @splitID
      $stderr.puts "on split dataset #{@splitID}"
    else
      $stderr.puts "on the complete training dataset" 
    end
    $stderr.puts "---------"
  end

  #####
  # perform
  #
  # do each of the inspection tasks set as options
  def perform()

    if @step == "both"
      # both? then do first argrec, then arglab
      $stderr.puts "Rosy training step argrec"
      @step = "argrec"
      perform_aux()
      $stderr.puts "Rosy training step arglab"
      @step = "arglab"
      perform_aux()
    else
      # not both? then just do one
      $stderr.puts "Rosy training step #{@step}"
      perform_aux()
    end
  end

  ###############
  private

  # perform_aux: do the actual work of the perform() method
  # moved here because of the possibility of having @step=="both",
  # which makes it necessary to perform two training steps one after the other
  def perform_aux()

    if @step == "arglab" and not(@exp.get("assume_argrec_perfect"))
    
      # KE Jan 31, 06: always redo computation of argrec on training data.
      # We have had trouble with leftover runlogs too often
        
      # i.e. apply argrec classifiers to argrec training data
      $stderr.puts "Rosy: Applying argrec classifiers to argrec training data"
      $stderr.puts "      to produce arglab training input"
      apply_obj = RosyTest.new(@exp,
                               { "--nooutput" => nil,
                                 "--logID" => @splitID,
                                 "--step" => "argrec"},
                               @ttt_obj, 
                               true) # argrec_apply: see above
      
      apply_obj.perform()
    end

    # hand all the info to the RosyIterator object
    # It will figure out what view I'll need.
    #
    # prune = true: If pruning has been enabled,
    # RosyIterator will add the appropriate DB column restrictions
    # such that pruned constituents do nto enter into training

    @iterator = RosyIterator.new(@ttt_obj, @exp, "train", 
				 "step" => @step, 
				 "splitID" => @splitID,
                                 "prune" => true)

    if @iterator.num_groups() == 0
      # no groups:
      # may have been a problem with pruning.
      $stderr.puts
      $stderr.puts "WARNING: NO DATA TO TRAIN ON."
      if Pruning.prune?(@exp)
        $stderr.puts "This may be a problem with pruning:"
        $stderr.print "Try removing the line starting in 'prune = ' "
        $stderr.puts "from your experiment file."
      end
      $stderr.puts
    end

    
    ####
    # get the list of relevant features,
    # remove the feature that describes the unit by which we train, 
    # since it is going to be constant throughout the training file
    @features = @ttt_obj.feature_info.get_model_features(@step) - 
                @iterator.get_xwise_column_names()
    # but add the gold feature
    unless @features.include? "gold"
      @features << "gold"
    end

    ####
    #for each frame/ for each target POS:
    classif_dir = classifier_directory_name(@exp,@step, @splitID)

    @iterator.each_group { |group_descr_hash, group|

      $stderr.puts "Training: " + group.to_s

      # get a view: model features, restrict frame/targetPOS to current group

      view = @iterator.get_a_view_for_current_group(@features)
      
      # make input file for classifiers:
      # one instance per line, comma-separated list of features,
      # last feature is the gold label.
      tf = Tempfile.new("rosy")
      
      view.each_instance_s { |instance_string|
        # change punctuation to _PUNCT_
        # and change empty space to _
        # because otherwise some classifiers may spit
        tf.puts prepare_output_for_classifiers(instance_string)
      }
      tf.close()

      # train classifiers
      @classifiers.each { |classifier, classifier_name|
        
        # if an explicit classifier dir is given, use that one
        output_name = classif_dir + @exp.instantiate("classifier_file",
                                                     "classif" => classifier_name,
                                                     "group" => group.gsub(/ /, "_"))
        classifier.train(tf.path(), output_name)
      }

      # clean up
      tf.close(true)
      view.close()
    }
    
  end
end
