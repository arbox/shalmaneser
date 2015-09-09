# RosyTest
# KE May 05
#
# One of the main task modules of Rosy:
# apply classifiers

# Standard library packages
require "tempfile"
require 'fileutils'

# Salsa packages
require "common/Parser"
# require "common/SalsaTigerRegXML"
require 'common/salsa_tiger_xml/salsa_tiger_sentence'
require "common/SynInterfaces"
require "common/ruby_class_extensions"
require "common/EnduserMode"

# Rosy packages
require "rosy/FeatureInfo"
require "common/ML"
require 'rosy/rosy_conventions'
require "rosy/RosyIterator"
require "rosy/RosyTask"
require "rosy/RosyTrainingTestTable"
require "rosy/View"

# Frprep packages
#require "common/prep_config_data" # AB: what the fuck???

##########################################################################
# classifier combination class
class ClassifierCombination

  # new(): just remember experiment file object
  def initialize(exp)
    @exp = exp
  end

  # combine:
  #
  # given a list of classifier results --
  # where a classifier result is a list of strings,
  # one string (= assigned class) for each instance,
  # and where each list of classifier results has the same length --
  # for each instance, combine individual classifier results
  # into a single judgement
  #
  # returns: an array of strings: one combined classifier result,
  # one string (=assigned class) for each instance
  def combine(classifier_results) #array:array:string, list of classifier results

    if classifier_results.length() == 1
      return classifier_results.first
    elsif classifier_results.length() == 0
      raise "Can't do classification with zero classifiers."
    else
      raise "True classifier combination not implemented yet"
    end
  end
end


##########################################################################
# main class in this package:
# applying classifiers
class RosyTest < RosyTask

  #####
  # new:
  #
  # initialize everything for applying classifiers
  #
  # argrec_apply: apply trained argrec classifiers to
  # training data, which means that almost everything is different
  def initialize(exp,      # RosyConfigData object: experiment description
                 opts,     # hash: runtime argument option (string) -> value (string)
                 ttt_obj,  # RosyTrainingTestTable object
                 argrec_apply = false) # boolean. true: see above

    ##
    # remember the experiment description

    @exp = exp
    @ttt_obj = ttt_obj
    @argrec_apply = argrec_apply

    ##
    # check runtime options

    # defaults:
    @step = "both"
    @splitID = nil
    @testID = Rosy.default_test_ID()
    @produce_output = true

    opts.each { |opt,arg|
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

      when "--nooutput"
        @produce_output = false

      else
        # this is an option that is okay but has already been read and used by rosy.rb
      end
    }

    ##
    # check: if this is about a split, do we have it?
    # if it is about a test, do we have it?
    if @splitID
      unless @ttt_obj.splitIDs().include?(@splitID)
        $stderr.puts "Sorry, I have no data for split ID #{@splitID}."
        exit 1
      end
    else
      if not(@argrec_apply) and not(@ttt_obj.testIDs().include?(@testID))
        $stderr.puts "Sorry, I have no data for test ID #{@testID}."
        exit 1
      end
    end

    ##
    # determine classifiers
    #
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

    # make classifier combination object
    @combinator = ClassifierCombination.new(@exp)

    if not(@argrec_apply)
      # normal run

      #####
      # Enduser mode: only steps "both" and "onestep" available.
      # testing only on test data, not on split data
      in_enduser_mode_ensure(["both", "onestep"].include?(@step))

      ##
      # add preprocessing information to the experiment file object
      # @note AB: Commented out due to separation of PrepConfigData:
      #   information for SynInteraces required.
      # if @splitID
      #   # use split data
      #   preproc_param = "preproc_descr_file_train"
      # else
      #   # use test data
      #   preproc_param = "preproc_descr_file_test"
      # end

      # preproc_expname = @exp.get(preproc_param)
      # if not(preproc_expname)
      #   $stderr.puts "Please set the name of the preprocessing exp. file name"
      #   $stderr.puts "in the experiment file, parameter #{preproc_param}."
      #   exit 1
      # elsif not(File.readable?(preproc_expname))
      #   $stderr.puts "Error in the experiment file:"
      #   $stderr.puts "Parameter #{preproc_param} has to be a readable file."
      #   exit 1
      # end
      # preproc_exp = FrPrepConfigData.new(preproc_expname)
      # @exp.adjoin(preproc_exp)

      # announce the task
      $stderr.puts "---------"
      $stderr.print "Rosy experiment #{@exp.get("experiment_ID")}: Testing "
      if @splitID
        $stderr.puts "on split dataset #{@splitID}"
      else
        $stderr.puts "on test dataset #{@testID}"
      end
      $stderr.puts "---------"
    end
  end


  ##################################################################
  # perform
  #
  # apply trained classifiers to the given (test) data
  def perform()
    if @step == "both"
      # both? then do first argrec, then arglab
      $stderr.puts "Rosy testing step argrec"

      previous_produce_output = @produce_output # no output in argrec
      @produce_output = false  # when performing both steps in a row

      @step = "argrec"
      perform_aux()

      $stderr.puts "Rosy testing step arglab"
      @produce_output = previous_produce_output
      @step = "arglab"
      perform_aux()
    else
      # not both? then just do one
      $stderr.puts "Rosy testing step " + @step
      perform_aux()
    end

    ####
    # Enduser mode: remove DB table with test data
    if $ENDUSER_MODE
      $stderr.puts "---"
      $stderr.puts "Cleanup: Removing DB table with test data."

      unless @testID
        raise "Shouldn't be here"
      end

      @ttt_obj.remove_test_table(@testID)
    end
  end

  ######################
  # get_result_column_name
  #
  # returns the column name for the current run,
  # i.e. the name of the column where this object's perform method
  # writes its data
  def get_result_column_name()
    return @run_column
  end

  #################################
  private

  # perform_aux: do the actual work of the perform() method
  # moved here because of the possibility of having @step=="both",
  # which makes it necessary to perform two test steps one after the other
  def perform_aux()

    @iterator, @run_column = get_iterator(true)

    ####
    # get the list of relevant features,
    # remove the features that describe the unit by which we train,
    # since they are going to be constant throughout the training file

    @features = @ttt_obj.feature_info.get_model_features(@step) -
                @iterator.get_xwise_column_names()

    # but add the gold feature
    unless @features.include? "gold"
      @features << "gold"
    end

    ####
    # for each group (as defined by the @iterator):
    # apply the group-specific classifier,
    # write the result into the database, into
    # the column named @run_column
    classif_dir = Rosy::classifier_directory_name(@exp, @step, @splitID)

    @iterator.each_group { |group_descr_hash, group|

      $stderr.puts "Applying classifiers to: " + group.to_s

      # get data for current group from database:

      # make a view: model features
      feature_view = @iterator.get_a_view_for_current_group(@features)

        if feature_view.length() == 0
        # no test data in this view: next group
        feature_view.close()
        next
      end

      # another view for writing the result
      result_view = @iterator.get_a_view_for_current_group([@run_column])

      # read trained classifiers
      # classifiers_read_okay: boolean, true if reading the stored classifier(s) succeeded
      classifiers_read_okay = true

      @classifiers.each { |classifier, classifier_name|

        stored_classifier = classif_dir +
              @exp.instantiate("classifier_file",
                               "classif" => classifier_name,
                                       "group" => group.gsub(/ /, "_"))

        status = classifier.read(stored_classifier)
        unless status
          STDERR.puts "[RosyTest] Error: could not read classifier."
          classifiers_read_okay = false
        end

      }

      classification_result = Array.new

      if classifiers_read_okay
        # apply classifiers, write result to database
        classification_result = apply_classifiers(feature_view, group, "test")
      end

      if classification_result == Array.new
        # either classifiers did not read OK, or some problem during classification:
        # label everything with NONE
        result_view.each_instance_s {|inst|
          classification_result << @exp.get("noval")
        }
      end

      result_view.update_column(@run_column,
                                classification_result)
      feature_view.close()
      result_view.close()
    }

    # pruning? then set the result for pruned nodes to "noval"
    # if we are doing argrec or onestep
    integrate_pruning_into_argrec_result()

    # postprocessing:
    # remove superfluous role labels, i.e. labels on nodes
    # whose ancestors already bear the same label
    if @step == "argrec" or @step == "onestep"

      $stderr.puts "Postprocessing..."

      # iterator for doing the postprocessing:
      # no pruning
      @postprocessing_iterator, dummy = get_iterator(false)

      @postprocessing_iterator.each_group { |group_descr_hash, group|

        view = @postprocessing_iterator.get_a_view_for_current_group(["nodeID", "sentid", @run_column])

        # remove superfluous labels, write the result back to the DB
        postprocess_classification(view, @run_column)
        view.close()
      }
    end


    # all went well, so confirm this run
    if @argrec_apply
      # argrec_apply: don't add preprocessing info again, and
      # get view maker for the training data
      @ttt_obj.confirm_runlog("argrec", "train", @testID, @splitID, @run_column)
    else
      # normal run
      @ttt_obj.confirm_runlog(@step, "test", @testID, @splitID, @run_column)
    end

    ####
    # If we are being asked to produce SalsaTigerXML output:
    # produce it.
    if @produce_output
      write_stxml_output()
    end
  end

  #########################
  # returns a pair [iterator, run_column]
  # for the current settings
  #
  # prune = true: If pruning has been enabled,
  # RosyIterator will add the appropriate DB column restrictions
  # such that pruned constituents do nto enter into training
  def get_iterator(prune)  #Boolean
    ##
    # make appropriate iterator object, get column name for the current run
    #
    if @argrec_apply
      # get view maker for the training data
      iterator = RosyIterator.new(@ttt_obj, @exp, "train",
                                   "step" => @step,
                                   "splitID" => @splitID,
                                   "prune" => prune)
      run_column = @ttt_obj.new_runlog("argrec", "train", @testID, @splitID)

    else
      # normal run

      # hand all the info to the RosyIterator object
      # It will figure out what view I'll need
      iterator = RosyIterator.new(@ttt_obj, @exp, "test",
                                  "step" => @step,
                                  "testID" => @testID,
                                  "splitID" => @splitID,
                                  "prune" => prune)

      run_column = @ttt_obj.new_runlog(@step, "test", @testID, @splitID)
    end

    return [iterator, run_column]
  end

  #########################
  # integrate pruning result into argrec result
  def integrate_pruning_into_argrec_result()
    if ["argrec", "onestep"].include? @step
      # we only need to integrate pruning results into argument recognition

      # get iterator that doesn't do pruning
      iterator, run_column = get_iterator(false)
      Pruning.integrate_pruning_into_run(run_column, iterator, @exp)
    end
  end

  #########################
  def apply_classifiers(view,  # DBView object: data to be classified
                        group,       # string: frame or target POS we are classifying
                        dataset)     # string: train/test

    # make input file for classifiers
    tf_input = Tempfile.new("rosy")
    view.each_instance_s { |instance_string|
      # change punctuation to _PUNCT_
      # and change empty space to _
      # because otherwise some classifiers may spit
      tf_input.puts Rosy::prepare_output_for_classifiers(instance_string)
    }
    tf_input.close()
    # make output file for classifiers
    tf_output = Tempfile.new("rosy")
    tf_output.close()

    ###
    # apply classifiers

    # classifier_results: array:array of strings, a list of classifier results,
    # each result a list of assigned classes(string), one class for each instance of the view
    classifier_results = Array.new

    @classifiers.each { |classifier, classifier_name|


      # did we manage to classify the test data?
      # there may be errors on the way (eg no training data)

      success = classifier.apply(tf_input.path(), tf_output.path())

      if success

        # read classifier output from file
        classifier_results << classifier.read_resultfile(tf_output.path()).map { |instance_result|
          # instance_result is a list of pairs [label, confidence]
          # such that the label with the highest confidence is first
          if instance_result.empty?
            # oops, no results
            nil
          else
            # label of the first label/confidence pair
            instance_result.first().first()
          end
        }.compact()

      else
        # error: return empty Array, so that error handling can take over in perform_aux()
        return Array.new
      end
    }

    # if we are here, all classifiers have succeeded...

    # clean up
    tf_input.close(true)
    tf_output.close(true)

    # combine classifiers
    return @combinator.combine(classifier_results)
  end

  ###
  # postprocess_classification
  #
  # given output of a learner,
  # postprocess the output:
  # map cases of
  #    FE
  #   /  \
  #       ...
  #       \
  #        FE
  #
  # to
  #    FE
  #   /  \
  #       ...
  #        \
  #        NONE
  def postprocess_classification(view, # DBView object: node IDs
                                 run_column) # string: name of current run column


    # keep new values for run_column for all rows in view
    # will be used for update in the end
    result = Array.new()

    view.each_sentence() { |sentence|

      # returns hash:
      # node index -> array of node indices: ancestors of the given node
      # indices are indices in the 'sentence' array
      ancestors = make_ancestor_hash(sentence)

      # test output
#       $stderr.puts "nodeID values:"
#       sentence.each_with_index  { |inst, index|
#         $stderr.puts "#{index}) #{inst["nodeID"]}"
#       }
#       $stderr.puts "\nAncestor hash:"
#       ancestors.each_pair { |node_ix, ancestors|
#         $stderr.puts "#{node_ix} -> " +  ancestors.map { |a| a.to_s }.join(", ")
#       }
#       $stderr.puts "press enter"
#       $stdin.gets()

      sentence.each_with_index { |instance, inst_index|

        # check whether this instance has an equally labeled ancestor
        has_equally_labeled_ancestor = false

        if (instance[run_column] != @exp.get("noval")) and
          ancestors[inst_index]

          if ancestors[inst_index].detect { |anc_index|
              sentence[anc_index][run_column] == instance[run_column]
            }
            has_equally_labeled_ancestor = true
          else
            has_equally_labeled_ancestor = false
          end
        end


        if has_equally_labeled_ancestor
          result << @exp.get("noval")
        else
          result << instance[run_column]
        end
      }
    }


#     # checking: how many labels have we deleted?
#     before = 0
#     view.each_sentence { |s|
#       s.each { |inst|
#       unless inst[run_column] == @exp.get("noval")
#         before += 1
#       end
#       }
#     }
#     after = 0
#     result.each { |r|
#       unless r == @exp.get("noval")
#       after += 1
#       end
#     }
#     $stderr.puts "Non-NONE labels before: #{before}"
#     $stderr.puts "Non-NONE labels after: #{after}"


    # update DB to new result
    view.update_column(run_column, result)
  end

  ##
  # make_ancestor_hash
  #
  # given a sentence as returned by view.each_sentence
  # (an array of hashes: column_name -> column_value),
  # use the column nodeID to map each instance of the sentence to its
  # ancestors
  #
  # returns: hash instanceID(integer) -> array:instanceIDs(integers)
  # mapping each instance to the list of its ancestors
  def make_ancestor_hash(sentence) # array:hash: column_name(string) -> column_value(object)
    # for each instance: find the parent
    # and store it in the parent_index hash
    parent_index = Hash.new


    # first make hash mapping each node ID to its index in the
    # 'sentence' array
    id_to_index = Hash.new()
    sentence.each_with_index { |instance, index|
      if instance["nodeID"]
        myID, parentID = instance["nodeID"].split()
        id_to_index[myID] = index
      else
        $stderr.puts "WARNING: no node ID for instance:\n"
        $stderr.puts instance.values.join(",")
      end
    }

    # now make hash mapping each node index to its parent index
    sentence.each { |instance|
      if instance["nodeID"]
        myID, parentID = instance["nodeID"].split()
        if parentID # root has no parent ID

          # sanity check: do I know the indices?
          if id_to_index[myID] and id_to_index[parentID]
            parent_index[id_to_index[myID]] = id_to_index[parentID]
          else
            $stderr.puts "RosyTest postprocessing WARNING: found ID for unseen nodes"
          end
        end
      else
        $stderr.puts "RosyTest postprocessing WARNING: no node ID for instance:\n"
        $stderr.puts instance.values.join(",")
      end
    }

    # for each instance: gather ancestor IDs
    # and store them in the ancestor_index hash
    ancestor_index = Hash.new

    parent_index.each_key { |node_index|
      ancestor_index[node_index] = Array.new
      ancestor = parent_index[node_index]

      while ancestor
        if ancestor_index[node_index].include? ancestor
          # we seem to have run into a loop
          # this should not happen, but it has happened anyway ;-)
#          STDERR.puts "Warning: node #{ancestor} is its own ancestor!"
          break
        end
        ancestor_index[node_index] << ancestor
        ancestor = parent_index[ancestor]
      end
    }
    return ancestor_index
  end

  ################
  # write_stxml_output
  #
  # Output the result of Rosy as SalsaTigerXML:
  # Take the input SalsaTigerXML data,
  # and write them to directory_output
  # (or, lacking that, to <rosy_dir>/<experiment_ID>/output),
  # taking over the frames from the input data
  # and supplanting any FEs that might be set in the input data
  # by the ones newly assigned by Rosy.
  def write_stxml_output()

    ##
    # determine input and output directory
    rosy_dir = File.new_dir(@exp.instantiate("rosy_dir",
                                             "exp_ID" => @exp.get("experiment_ID")))
    if @splitID
      # split data is being used: part of the training data
      input_directory = File.existing_dir(rosy_dir,"input_dir/train")
    else
      # test data is being used
      input_directory = File.existing_dir(rosy_dir, "input_dir/test")
    end


    if @exp.get("directory_output")
      # user has set an explicit output directory
      output_directory = File.new_dir(@exp.get("directory_output"))
    else
      # no output directory has been set: use default
      output_directory = File.new_dir(@exp.instantiate("rosy_dir", "exp_ID" => @exp.get("experiment_ID")),
                                      "output")
    end

    ###
    # find appropriate class for interpreting syntactic structures
    interpreter_class = SynInterfaces.get_interpreter_according_to_exp(@exp)


    $stderr.puts "Writing SalsaTigerXML output to #{output_directory}"

    ###
    # read in all FEs that have been assigned
    # sentid_to_assigned: hash <sent ID, frame ID> (string) -> array of pairs [FE, node ID]
    sentid_to_assigned = Hash.new
    @iterator.each_group { |group_descr_hash, group|
      view = @iterator.get_a_view_for_current_group([@run_column, "nodeID", "sentid"])

      view.each_hash { |inst_hash|
        # if this sentence ID/frame ID pair is in the test data,
        # its hash entry will at least be nonnil, even if no
        # FEs have been assigned for it
        unless sentid_to_assigned[inst_hash["sentid"]]
          sentid_to_assigned[inst_hash["sentid"]] = Array.new
        end

        # if nothing has been assigned to this instance, don't record it
        if inst_hash[@run_column].nil? or inst_hash[@run_column] == @exp.get("noval")
          next
        end

        # record instance
        sentid_to_assigned[inst_hash["sentid"]] << [inst_hash[@run_column], inst_hash["nodeID"]]
      }
      view.close()
    }

    ###
    # write stuff

    ##
    # iterate through input files
    Dir[input_directory + "*.xml.gz"].each { |infilename|

      # unpack input file
      tempfile = Tempfile.new("RosyTest")
      tempfile.close()
      %x{gunzip -c #{infilename} > #{tempfile.path()}}

      # open input and output file
      infile = FilePartsParser.new(tempfile.path())
      outfilename = output_directory + File.basename(infilename, ".gz")
      begin
        outfile = File.new(outfilename, "w")
      rescue
        raise "Could not write to SalsaTigerXML output file #{outfilename}"
      end

      # write header to output file
      outfile.puts infile.head()

      ##
      # each input sentence: integrate newly assigned roles
      infile.scan_s { |sent_string|
        sent = SalsaTigerSentence.new(sent_string)

        ##
        # each input frame: remove old roles, add new ones
        sent.frames.each { |frame|

          # this corresponds to the sentid feature in the database
          sent_frame_id = Rosy::construct_instance_id(sent.id, frame.id)

          if sentid_to_assigned[sent_frame_id].nil? and @splitID
            # we are using a split of the training data, and
            # this sentence/frame ID pair does not
            # seem to be in the test part of the split
            # so do not show the frame
            #
            # Note that if we are _not_ working on a split,
            # we are not discarding any frames or sentences
            sent.remove_frame(frame)
          end

          # remove old roles, but do not remove target
          old_fes = frame.children()
          old_fes.each { |old_fe|
            unless old_fe.name() == "target"
              frame.remove_child(old_fe)
            end
          }

          if sentid_to_assigned[sent_frame_id].nil?
            # nothing assigned to this frame -- go on
            next
          end

          # assign new roles:
          # each FE occurring for this sentence ID plus frame ID:
          # collect all node ID / parentnode ID pairs listed for that FE,
          # map the IDs to actual nodes, and assign the FE.
          sentid_to_assigned[sent_frame_id].map { |fe_name, npp| fe_name }.uniq.each { |fe_name|
            # each FE

            nodes = sentid_to_assigned[sent_frame_id].select { |other_fe_name, npp|
              # collect node ID / parentnode ID pairs listed for that FE
              other_fe_name == fe_name

            }.map { |other_fe_name, nodeid_plus_parent_id|
              # map the node ID / parentnode ID pair to an actual node

              node_id, parent_id = nodeid_plus_parent_id.split()
              if node_id == @exp.get("noval")
                $stderr.puts "Warning: got NONE for a node ID"
                node = nil

              else
                node = sent.syn_node_with_id(node_id)
                unless node
                  $stderr.puts "Warning: could not find node with ID #{node_id}"
                end
              end

              node
            }.compact

            # assign the FE
            sent.add_fe(frame, fe_name, interpreter_class.max_constituents(nodes, sent))
          } # each FE
        } # each frame

        # write changed sentence to output file
        # if we are working on a split of the training data,
        # write the sentence only if there are frames in it
        if sent.frames.length() == 0 and @splitID
          # split of the training data, and no frames
        else
          outfile.puts sent.get()
        end
      } # each sentence

      # write footer to output file
      outfile.puts infile.tail()
      tempfile.close(true)
    } # each input file
  end
end
