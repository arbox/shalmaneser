# -*- coding: utf-8 -*-
# FredTest
# Katrin Erk April 05
#
# Frame disambiguation system: 
# apply trained classifiers to test data
# Results are written out one output line per instance line.

# Ruby packages
require "tempfile"

# Salsa packages
require "common/Parser"
require "common/RegXML"
require "common/SalsaTigerRegXML"
require "common/StandardPkgExtensions"

# Shalmaneser packages
require "common/FrPrepConfigData"
require "common/ML"
require "fred/Baseline"
require "fred/FredConventions"
require "fred/FredDetermineTargets"
require "fred/FredSplitPkg"
require "fred/FredFeatures"
require "fred/FredNumTrainingSenses"

class FredTest

  ###
  # new
  #
  # evaluate runtime options and announce the task
  def initialize(exp_obj, # FredConfigData object
		 options) # hash: runtime option name (string) => value(string)

    # keep the experiment file object
    @exp = exp_obj

    # evaluate runtime options
    @split_id = nil
    @baseline = false
    @produce_output = true

    options.each_pair { |opt, arg|
      case opt
      when "--logID"
	
	@split_id = arg

      when "--baseline"
	@baseline = true

      when "--nooutput"
        @produce_output = false

      else
	# case of unknown arguments has been dealt with by fred.rb
      end
    }

    # announce the task
    $stderr.puts "---------"
    $stderr.print "Fred  experiment #{@exp.get("experiment_ID")}: "
    if @baseline
      $stderr.print "Computing baseline "
    else
      $stderr.print "Applying classifiers"
    end
    if @split_id
      $stderr.puts " using split with ID #{@split_id}"
    else
      $stderr.puts
    end
    if @produce_output and not @split_id
      $stderr.print "Output is to "
      if @exp.get("directory_output")
        $stderr.puts @exp.get("directory_output")
      else
        $stderr.puts fred_dirname(@exp, "output", "stxml", "new")
      end
    end
    $stderr.puts "---------"

    ###
    # prepare data:

    if @baseline
      # only compute baseline: always assign most frequent sense
      
      @classifiers = [
                      [Baseline.new(@exp, @split_id), "baseline"]
                     ]

    else
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
        $stderr.puts "Error: I need at least one classifier, please specify using exp. file option 'classifier'"
        exit 1
      end      


      if @classifiers.length() > 1
        $stderr.puts "Warning: I'm not doing classifier combination at the moment,"
        $stderr.puts "so I'll be ignoring all but the first classifier type."
      end
    end

    # get an object for listing senses of each lemma
    @lemmas_and_senses = Targets.new(@exp, nil, "r")
  end

  ###
  # compute
  #
  # classify test instances,
  # write output to file.
  def compute()
    if @split_id
      # make split object and parameter hash to pass to it.
      # read feature data from training feature directory.
      split_obj = FredSplitPkg.new(@exp)
      dataset = "train"
    else
      # read feature data from test feature directory.
      dataset = "test"
    end

    output_dir = fred_dirname(@exp, "output", "tab", "new")
    classif_dir = fred_classifier_directory(@exp, @split_id)

    ###
    # remove old classifier output files
    Dir[output_dir + "*"].each { |f|
      if File.exists? f
        File.delete(f)
      end
    }


    all_results = Array.new()

    ###
    # get a list of all relevant feature files: lemma, sense?
    lemma2_sense_and_filename = Hash.new()

    FredFeatureAccess.each_feature_file(@exp, dataset) { |filename, values|

      # catalogue under lemma
      unless lemma2_sense_and_filename[values["lemma"]]
        lemma2_sense_and_filename[values["lemma"]] = Array.new()
      end
      # catalogue only matches between chosen classifier type
      # and actually existing classifier type

# hier checken
# senses ist nil,  lemma2_sense_and_filename wird nicht gefüllt 
# => es werden keine classifier gefunden


      if @exp.get("binary_classifiers") and \
        values["sense"] and not(values["sense"].empty?)
        lemma2_sense_and_filename[values["lemma"]] << [values["sense"], filename]

      elsif not(@exp.get("binary_classifiers")) and \
        (values["sense"].nil? or values["sense"].empty?)
        lemma2_sense_and_filename[values["lemma"]] << [nil, filename]
      end        
    }

    ###
    # check whether we have classifiers
    found = 0
    found_single_sense = 0
    lemma2_sense_and_filename.each_pair { |lemma, senses_and_filenames|
      if @lemmas_and_senses.get_senses(lemma).length() == 1
        # lemma with only one sense? then mark as such
        found_single_sense += 1
      else
        # lemma with more than one sense: look for classifiers
        senses_and_filenames.each { |sense, filename|
          @classifiers.each { |classifier, classifier_name|
            if @exp.get("binary_classifiers") and \
              classifier.exists? classif_dir + fred_classifier_filename(classifier_name, 
                                                                        lemma, sense)
              found += 1
            elsif not(@exp.get("binary_classifiers")) and\
              classifier.exists? classif_dir + fred_classifier_filename(classifier_name, 
                                                                        lemma)
              found += 1
            end
          }
        }
      end
    }
    if found == 0 and found_single_sense < lemma2_sense_and_filename.length()
      # no matching classifiers found
      $stderr.puts "ERROR: no classifiers found in #{classif_dir}."
      if @exp.get("binary_classifiers")
        $stderr.puts "(Looking for binary classifiers.)"
      else
        $stderr.puts "(Looking for n-ary classifiers.)"
      end
      $stderr.puts "Please check whether you mistyped the classifier directory name.
      
Another possibility: You may have trained binary classifiers, but
tried to apply n-ary ones (or vice versa.)
"
      exit 1
    end

    ###
    # each test feature set:
    # read classifier, apply
    # iterate through instance files
    lemma2_sense_and_filename.to_a().sort { |a, b|
      a.first() <=> b.first
    }.each { |lemma, senses_and_filenames|
      # progress report
      if @exp.get("verbose")
        $stderr.puts "Applying to " + lemma
      end

      # results_this_lemma: array of classifier_results
      # classifier_result: array of line_entries
      # line entry: list of pairs [sense, confidence]
      results_this_lemma = Array.new()

      training_senses = determine_training_senses(lemma, @exp, 
                                                  @lemmas_and_senses, @split_id)

      senses_and_filenames.each { |sense, filename|

        # if we're splitting the data, do that now
        if split_obj
          tempfile = split_obj.apply_split(filename, lemma, "test", @split_id)
          if tempfile.nil?
            # the test part of the split doesn't contain any data
            $stderr.puts "Skipping #{lemma}: no test data in split"
            next
          end

          filename = tempfile.path()
        end

        if training_senses.length() == 1
          # single-sense lemma: just assign that sense to all occurrences
          assigned_sense = training_senses.first()

          classifier_result = Array.new()
          f = File.open(filename)

          f.each { |line| classifier_result << [[assigned_sense, 1.0]] }
          results_this_lemma << classifier_result

        else
          #more than one sense: apply classifier(s)

          # classifiers_read_okay: 
          # boolean, true if reading the stored classifier(s) succeeded
          classifiers_read_okay = true
          @classifiers.each { |classifier, classifier_name| 
            
            stored_classifier = classif_dir +  fred_classifier_filename(classifier_name, 
                                                                      lemma, sense)
            status = classifier.read(stored_classifier)
            unless status
              $stderr.puts "[FredTest] Error: could not read classifier."
              classifiers_read_okay = false
            end
          }

          if classifiers_read_okay        
            # apply classifiers, write result to database
            classifier_results = apply_classifiers(filename, classif_dir)

            if classifier_results.empty?
              # something went wrong during the application of classifiers
              $stderr.puts "Error while working on #{lemma}, skipping"
            else
              # we have classifier results:
              # since we're not doing any classifier combination at the moment
              # (if we did, this would be the place to do so!)
            # discard the results of all but the first classifier
              results_this_lemma << classifier_results.first()
            end
          end

          if split_obj
            tempfile.close(true)
          end
        end
      }

      # write to output file:
      # if we have binary classifiers, join.
      results_this_lemma = join_binary_classifier_results(results_this_lemma)

      outfilename = output_dir + fred_result_filename(lemma)
      begin
        outfile = File.new(outfilename, "w")
      rescue
        raise "Couldn't write to result file " + outfilename
      end
      
      if results_this_lemma.nil?
        # nothing has been done for this lemma
        next
      end

      results_this_lemma.each { |result|
        # result: an ordered list of pairs [label, confidence]
        outfile.puts result.map { |label, confidence|
          "#{label} #{confidence}"
        }.join(" ")
      }

      # remember results for output
      if @produce_output
        all_results << [lemma, results_this_lemma]
      end
    }


    ##
    # produce output: disambiguated data in SalsaTigerXML format
    if @produce_output
      salsatiger_output(all_results)
    end

  end

  #####
  private

  #########################
  def apply_classifiers(filename,    # name of feature file
                        classif_dir) # string: name of directory with classifiers
                        
    # make output file for classifiers
    tf_output = Tempfile.new("fred")
    tf_output.close()

    ###
    # apply classifiers
    
    classifier_results = Array.new

    @classifiers.each { |classifier, classifier_name|

      success = classifier.apply(filename, tf_output.path())

      # did we manage to classify the test data?      
      # there may be errors on the way (eg no training data)      
      if success
        # read classifier output from file
        # classifier_results: list of line entries
        # line entry: list of pairs [sense, confidence]
        classifier_results << classifier.read_resultfile(tf_output.path())
        
      else
        # error: return empty Array, so that error handling can take over
        return Array.new
      end
    }

    # if we are here, all classifiers have succeeded... 
    
    # clean up
    tf_output.close(true)

    # return list of classifier results,
    # each entry is a list of results,
    # one entry per classifier type
    return classifier_results
  end

  ###
  # join binary classifier results (if we are doing binary classifiers):
  # if we have classifiers that are specific to individual senses,
  # collect all classifiers that we have for a lemma, and
  # for each instance, choose the sense that won with the highest confidence
  #
  # input: a list of result lists.
  #  a result list is a list of instance_results
  #  instance_results is a list of pairs [label, confidence]
  #  such that the label with the highest confidence is mentioned first
  #
  # output: a result list.
  def join_binary_classifier_results(resultlists) # list:list:tuples [label, confidence]
    unless @exp.get("binary_classifiers")
      # we are doing lemma-specific, not sense-specific classifiers.
      # so resultlist is a list containing just one entry.
      #   all classifier: list of lists of lists of pairs label, confidence
      #   one classifier: list of lists of pairs label, confidence
      #   line: list of pairs label, confidence
      #   label: pair label, confidence
      return resultlists.first()
    end

    # we are doing sense-specific classifiers.
    # group triples 

    # what is the name of the negative sense?
    unless (negsense = @exp.get("negsense"))
      negsense = "NONE"
    end

    # retv: list of instance results
    # where an instance result is a list of pairs [label, confidence]
    retv = Array.new()

    # choose the sense that was assigned with highest confidence
    # how many instances? max. length of any of the instance lists
    # (we'll deal with mismatches in instance numbers later)
    num_instances = resultlists.map { |list_one_classifier| list_one_classifier.length() }.max()
    if num_instances.nil?
      # no instances, it seems
      return nil
    end
    
    0.upto(num_instances - 1) { |instno|

      # get the results of all classifiers for instance number instno
      all_results_this_instance = resultlists.map { |list_one_classifier|
        # get the instno-th line
        if list_one_classifier.at(instno)
          list_one_classifier.at(instno)
        else
          # length mismatch: we're missing an instance
          $stderr.puts "Error: binary classifier results don't all have the same length."
          $stderr.puts "Assuming missing results to be negative."
          [["NONE", 1.0]]
        end
      }

      # now throw out the negsense judgments, and sort results by confidence
      joint_result_this_instance = all_results_this_instance.map { |inst_result|
        # if we have more than 2 entries here, 
        # this is very weird for a binary classifier
        if inst_result.length() > 2
          $stderr.puts "Judgments for more than 2 senses in binary classifier? Very weird!"
          $stderr.puts inst_result.map { |label, confidence| "#{label}:#{confidence}" }.join(" ")
          $stderr.puts "Only considering the first non-negative sense."
        end

        # choose the first entry that is not the negsense,
        # or nil, if only the negative sense has been assigned with 1.0 certainty.
        # nil choices will be removed by the compact() below
        inst_result.detect { |label, confidence|
          label != negsense
        }
      }.compact().sort { |a, b|
        # sort senses by confidence, highest confidence first
        b[1] <=> a[1]
      }
      
      retv << joint_result_this_instance
    }

    return retv
  end


  ###
  # produce output in SalsaTigerXML: disambiguated training data,
  # assigned senses are recorded as frames, the targets of which are the
  # disambiguated words
  def salsatiger_output(all_results)

    if @split_id
      # we're not writing Salsa/Tiger XML output for splits.
      $stderr.puts "No Salsa/Tiger XML output for random splits of the data,"
      $stderr.puts "only for separate test sets."
      return
    end

    ##
    # determine output directory
    if @exp.get("directory_output")
      output_dir = File.new_dir(@exp.get("directory_output"))
    else
      output_dir = fred_dirname(@exp, "output", "stxml", "new")
    end

    $stderr.puts "Writing SalsaTigerXML output to #{output_dir}"

    ##
    # empty output directory
    Dir[output_dir + "*"].each { |filename|
      if File.exists?(filename)
        File.delete(filename)
      end
    }

    # input directory: where we stored the zipped input files
    input_dir = fred_dirname(@exp, "test", "input_data")

    ##
    # map results to target IDs, using answer key files

    # record results: hash 
    # <sentencde ID>(string) -> assigned senses
    # where assigned senses are a list of tuples 
    # [target IDs, sense, lemma, pos]
    recorded_results = Hash.new

    all_results.each { |lemma, results|
      answer_obj = AnswerKeyAccess.new(@exp, "test", lemma, "r")

      instance_index = 0
      answer_obj.each { |a_lemma, a_pos, a_targetIDs, a_sid, a_senses, a_senses_this|
        key = a_sid

        unless recorded_results[key]
          recorded_results[key] = Array.new()
        end

        labels_and_senses_for_this_instance = results.at(instance_index)
        if not(labels_and_senses_for_this_instance.empty?) and 
            (winning_sense = labels_and_senses_for_this_instance.first().first())
            
          recorded_results[key] << [a_targetIDs, winning_sense, a_lemma, a_pos]
        end

        instance_index += 1
      } # each answerkey line for this lemma
    } # each lemma/results pair


    ##
    # read in SalsaTiger syntax, remove old semantics, add new semantics, write

    Dir[input_dir + "*.xml.gz"].each { |filename|
      # unzip input file
      tempfile = Tempfile.new("FredTest")
      tempfile.close()
      %x{gunzip -c #{filename} > #{tempfile.path()}}

      infile = FilePartsParser.new(tempfile.path())
      if @exp.get("verbose")
        $stderr.puts "SalsaTigerXML output of " + File.basename(filename, ".gz")
      end

      begin
        outfile = File.new(output_dir + File.basename(filename, ".gz"), "w")
      rescue
        $stderr.puts "Couldn't write to output file #{output_dir}#{File.basename(filename)}."
        $stderr.puts "Skipping Salsa/Tiger XML output."
        return
      end

      # write header
      outfile.puts infile.head()

      infile.scan_s { |sent_string|
        sent = SalsaTigerSentence.new(sent_string)

        # remove old semantics
        sent.remove_semantics()

        if recorded_results and recorded_results[sent.id()]
          recorded_results[sent.id()].each { |target_ids, sense, lemma, pos|

            # add frame to sentence
            new_frame = sent.add_frame(sense)
            
            # get list of target nodes from target IDs
            # assuming that target_ids is a string of target IDs
            # separated by comma.
            # IDs for which no node could be found are just ignored

            targets = target_ids.map { |target_id|
              sent.syn_node_with_id(target_id)
            }.compact
            # enter the target nodes for this new frame
            new_frame.add_fe("target", targets)
            
          # put lemma and POS info into <target>
            new_frame.target.set_attribute("lemma", lemma)
            new_frame.target.set_attribute("pos", pos)
          }
        end
            
        # write changed sentence: 
        # only if there are recorded results for this sentence!
        outfile.puts sent.get()
          
      } # each sentence of file 

      # write footer
      outfile.puts infile.tail()
      outfile.close()
      tempfile.close(true)
    } # each SalsaTiger file of the input directory
    
  end

end
