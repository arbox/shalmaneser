# -*- coding: utf-8 -*-
# FredTest
# Katrin Erk April 05
#
# Frame disambiguation system:
# apply trained classifiers to test data
# Results are written out one output line per instance line.

# Ruby packages
require "tempfile"

require 'salsa_tiger_xml/salsa_tiger_sentence'
require "ruby_class_extensions"

# Shalmaneser packages
require 'ml/classifier'
require 'fred/baseline'
require 'fred/FredConventions' # !
require 'fred/targets'
require 'fred/fred_split_pkg'
# require "fred/FredFeatures"
require 'fred/fred_feature_access'
require 'fred/answer_key_access'

require 'salsa_tiger_xml/file_parts_parser'

require 'logging'
require 'fred/fred_error'
require_relative 'task'

module Shalmaneser
  module Fred
    class FredTest < Task
      #
      # evaluate runtime options and announce the task
      # FredConfigData object
      # hash: runtime option name (string) => value(string)
      def initialize(exp_obj, options)
        @exp = exp_obj

        # evaluate runtime options
        @split_id = nil
        @baseline = false
        @produce_output = true

        options.each_pair do |opt, arg|
          case opt
          when "--logID"
            @split_id = arg
          when "--baseline"
            @baseline = true
          when "--nooutput"
            @produce_output = false
          end

          # prepare data:
          if @baseline
            # only compute baseline: always assign most frequent sense
            @classifiers = [[Baseline.new(@exp, @split_id), "baseline"]]
          else
            # determine classifiers
            # get_lf returns: array of pairs [classifier_name, options[array]]
            # @classifiers: list of pairs [Classifier object, classifier name(string)]
            @classifiers = @exp.get_lf("classifier").map do |classif_name, options|
              [Classifier.new(classif_name, options), classif_name]
            end

            # @todo AB: Move this to ConfigData.
            # sanity check: we need at least one classifier
            if @classifiers.empty?
              raise FredError, "Error: I need at least one classifier, please specify using exp. file option 'classifier'"
            end


            if @classifiers.length > 1
              LOGGER.warn "Warning: I'm not doing classifier combination at the moment, "\
                          "so I'll be ignoring all but the first classifier type."
            end
          end

          # get an object for listing senses of each lemma
          @lemmas_and_senses = Targets.new(@exp, nil, "r")
        end
      end

      ###
      # compute
      #
      # classify test instances,
      # write output to file.
      def compute
        # announce the task
        LOGGER.info "Fred experiment #{@exp.get("experiment_ID")}: "
        if @baseline
          LOGGER.info "Computing baseline "
        else
          LOGGER.info "Applying classifiers"
        end

        if @split_id
          LOGGER.info " using split with ID #{@split_id}"
        end

        if @produce_output and not @split_id
          LOGGER.info "Output is to "
          if @exp.get("directory_output")
            LOGGER.info @exp.get("directory_output")
          else
            LOGGER.info ::Shalmaneser::Fred.fred_dirname(@exp, "output", "stxml", "new")
          end
        end

        ###
        if @split_id
          # make split object and parameter hash to pass to it.
          # read feature data from training feature directory.
          split_obj = FredSplitPkg.new(@exp)
          dataset = "train"
        else
          # read feature data from test feature directory.
          dataset = "test"
        end

        output_dir = ::Shalmaneser::Fred.fred_dirname(@exp, "output", "tab", "new")
        classif_dir = ::Shalmaneser::Fred.fred_classifier_directory(@exp, @split_id)

        ###
        # remove old classifier output files
        # @todo AB: This is nonsense!
        Dir[output_dir + "*"].each do |f|
          if File.exist?(f)
            File.delete(f)
          end
        end

        all_results = []

        ###
        # get a list of all relevant feature files: lemma, sense?
        lemma2_sense_and_filename = {}

        FredFeatureAccess.each_feature_file(@exp, dataset) do |filename, values|
          # catalogue under lemma
          unless lemma2_sense_and_filename[values["lemma"]]
            lemma2_sense_and_filename[values["lemma"]] = []
          end
          # catalogue only matches between chosen classifier type
          # and actually existing classifier type

          # hier checken
          # senses ist nil,  lemma2_sense_and_filename wird nicht gefüllt
          # => es werden keine classifier gefunden
          if @exp.get("binary_classifiers") and values["sense"] and not(values["sense"].empty?)
            lemma2_sense_and_filename[values["lemma"]] << [values["sense"], filename]

          elsif not(@exp.get("binary_classifiers")) and (values["sense"].nil? or values["sense"].empty?)
            lemma2_sense_and_filename[values["lemma"]] << [nil, filename]
          end
        end

        ###
        # check whether we have classifiers
        found = 0
        found_single_sense = 0
        lemma2_sense_and_filename.each_pair do |lemma, senses_and_filenames|
          if @lemmas_and_senses.get_senses(lemma).length == 1
            # lemma with only one sense? then mark as such
            found_single_sense += 1
          else
            # lemma with more than one sense: look for classifiers
            senses_and_filenames.each do |sense, filename|
              @classifiers.each do |classifier, classifier_name|
                if @exp.get("binary_classifiers") and classifier.exists? classif_dir + ::Shalmaneser::Fred.fred_classifier_filename(classifier_name, lemma, sense)
                  found += 1
                elsif not(@exp.get("binary_classifiers")) and classifier.exists? classif_dir + ::Shalmaneser::Fred.fred_classifier_filename(classifier_name, lemma)
                  found += 1
                end
              end
            end
          end
        end

        if found == 0 and found_single_sense < lemma2_sense_and_filename.length
          # no matching classifiers found
          LOGGER.fatal "ERROR: no classifiers found in #{classif_dir}."
          if @exp.get("binary_classifiers")
            LOGGER.fatal "(Looking for binary classifiers.)"
          else
            LOGGER.fatal "(Looking for n-ary classifiers.)"
          end
          LOGGER.fatal "Please check whether you mistyped the classifier directory name."\
                       "Another possibility: You may have trained binary classifiers, but"\
                       "tried to apply n-ary ones (or vice versa.)"
          raise FredError
        end

        ###
        # each test feature set:
        # read classifier, apply
        # iterate through instance files
        lemma2_sense_and_filename.to_a.sort { |a, b| a.first <=> b.first }.each { |lemma, senses_and_filenames|
          # progress report
          LOGGER.debug "Applying to #{lemma}."

          # results_this_lemma: array of classifier_results
          # classifier_result: array of line_entries
          # line entry: list of pairs [sense, confidence]
          results_this_lemma = []

          training_senses = determine_training_senses(lemma, @exp,
                                                      @lemmas_and_senses,
                                                      @split_id)

          senses_and_filenames.each { |sense, filename|

            # if we're splitting the data, do that now
            if split_obj
              tempfile = split_obj.apply_split(filename, lemma, "test", @split_id)
              if tempfile.nil?
                # the test part of the split doesn't contain any data
                $stderr.puts "Skipping #{lemma}: no test data in split"
                next
              end

              filename = tempfile.path
            end

            if training_senses.length == 1
              # single-sense lemma: just assign that sense to all occurrences
              assigned_sense = training_senses.first

              classifier_result = []
              f = File.open(filename)

              f.each { |line| classifier_result << [[assigned_sense, 1.0]] }
              results_this_lemma << classifier_result

            else
              #more than one sense: apply classifier(s)

              # classifiers_read_okay:
              # boolean, true if reading the stored classifier(s) succeeded
              classifiers_read_okay = true
              @classifiers.each do |classifier, classifier_name|
                stored_classifier = classif_dir + ::Shalmaneser::Fred.fred_classifier_filename(classifier_name, lemma, sense)
                status = classifier.read(stored_classifier)
                unless status
                  $stderr.puts "[FredTest] Error: could not read classifier."
                  classifiers_read_okay = false
                end
              end

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
                  results_this_lemma << classifier_results.first
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

          outfilename = output_dir + ::Shalmaneser::Fred.fred_result_filename(lemma)
          begin
            outfile = File.new(outfilename, "w")
          rescue
            raise "Couldn't write to result file " + outfilename
          end

          if results_this_lemma.nil?
            # nothing has been done for this lemma
            next
          end

          results_this_lemma.each do |result|
            # result: an ordered list of pairs [label, confidence]
            outfile.puts result.map { |label, confidence|
              "#{label} #{confidence}"
            }.join(" ")
          end

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
      #     # name of feature file
      # string: name of directory with classifiers
      def apply_classifiers(filename, classif_dir)
        # make output file for classifiers
        tf_output = Tempfile.new("fred")
        tf_output.close

        ###
        # apply classifiers

        classifier_results = []

        @classifiers.each do |classifier, classifier_name|
          success = classifier.apply(filename, tf_output.path)

          # did we manage to classify the test data?
          # there may be errors on the way (eg no training data)
          if success
            # read classifier output from file
            # classifier_results: list of line entries
            # line entry: list of pairs [sense, confidence]
            classifier_results << classifier.read_resultfile(tf_output.path)
          else
            # error: return empty Array, so that error handling can take over
            return []
          end
        end

        # if we are here, all classifiers have succeeded...

        # clean up
        tf_output.close(true)

        # return list of classifier results,
        # each entry is a list of results,
        # one entry per classifier type
        classifier_results
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
          return resultlists.first
        end

        # we are doing sense-specific classifiers.
        # group triples

        # what is the name of the negative sense?
        unless (negsense = @exp.get("negsense"))
          negsense = "NONE"
        end

        # retv: list of instance results
        # where an instance result is a list of pairs [label, confidence]
        retv = []

        # choose the sense that was assigned with highest confidence
        # how many instances? max. length of any of the instance lists
        # (we'll deal with mismatches in instance numbers later)
        num_instances = resultlists.map { |list_one_classifier| list_one_classifier.length }.max
        if num_instances.nil?
          # no instances, it seems
          return nil
        end

        0.upto(num_instances - 1) { |instno|

          # get the results of all classifiers for instance number instno
          all_results_this_instance = resultlists.map do |list_one_classifier|
            # get the instno-th line
            if list_one_classifier.at(instno)
              list_one_classifier.at(instno)
            else
              # length mismatch: we're missing an instance
              LOGGER.error "Error: binary classifier results don't all have the same length."\
                           "\nAssuming missing results to be negative."
              [["NONE", 1.0]]
            end
          end

          # now throw out the negsense judgments, and sort results by confidence
          joint_result_this_instance = all_results_this_instance.map do |inst_result|
            # if we have more than 2 entries here,
            # this is very weird for a binary classifier
            if inst_result.length > 2
              LOGGER.warn "Judgments for more than 2 senses in binary classifier? Very weird!"
              LOGGER.warn inst_result.map { |label, confidence| "#{label}:#{confidence}" }.join(" ")
              LOGGER.warn "Only considering the first non-negative sense."
            end

            # choose the first entry that is not the negsense,
            # or nil, if only the negative sense has been assigned with 1.0 certainty.
            # nil choices will be removed by the compact() below
            inst_result.detect { |label, confidence| label != negsense }
          end.compact.sort do |a, b|
            # sort senses by confidence, highest confidence first
            b[1] <=> a[1]
          end

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
          LOGGER.warn "No Salsa/Tiger XML output for random splits of the data,"\
                      "only for separate test sets."
          return
        end

        ##
        # determine output directory
        if @exp.get("directory_output")
          output_dir = File.new_dir(@exp.get("directory_output"))
        else
          output_dir = ::Shalmaneser::Fred.fred_dirname(@exp, "output", "stxml", "new")
        end

        LOGGER.info "Writing SalsaTigerXML output to #{output_dir}"

        ##
        # empty output directory
        Dir[output_dir + "*"].each { |filename|
          if File.exist?(filename)
            File.delete(filename)
          end
        }

        # input directory: where we stored the zipped input files
        input_dir = ::Shalmaneser::Fred.fred_dirname(@exp, "test", "input_data")

        ##
        # map results to target IDs, using answer key files

        # record results: hash
        # <sentencde ID>(string) -> assigned senses
        # where assigned senses are a list of tuples
        # [target IDs, sense, lemma, pos]
        recorded_results = {}

        all_results.each do |lemma, results|
          answer_obj = AnswerKeyAccess.new(@exp, "test", lemma, "r")

          instance_index = 0
          answer_obj.each do |a_lemma, a_pos, a_targetIDs, a_sid, a_senses, a_senses_this|
            key = a_sid

            unless recorded_results[key]
              recorded_results[key] = []
            end

            labels_and_senses_for_this_instance = results.at(instance_index)
            if not(labels_and_senses_for_this_instance.empty?) and
              (winning_sense = labels_and_senses_for_this_instance.first.first)

              recorded_results[key] << [a_targetIDs, winning_sense, a_lemma, a_pos]
            end

            instance_index += 1
          end # each answerkey line for this lemma
        end # each lemma/results pair


        ##
        # read in SalsaTiger syntax, remove old semantics, add new semantics, write

        Dir[input_dir + "*.xml.gz"].each { |filename|
          # unzip input file
          tempfile = Tempfile.new("FredTest")
          tempfile.close
          # @todo AB: Replace this with a native call.
          %x{gunzip -c #{filename} > #{tempfile.path}}

          infile = STXML::FilePartsParser.new(tempfile.path)

          LOGGER.debug "SalsaTigerXML output of " + File.basename(filename, ".gz")

          begin
            outfile = File.new(output_dir + File.basename(filename, ".gz"), "w")
          rescue
            LOGGER.warn "Couldn't write to output file #{output_dir}#{File.basename(filename)}.\n"\
                        "Skipping Salsa/Tiger XML output."
            return
          end

          # write header
          outfile.puts infile.head

          infile.scan_s { |sent_string|
            sent = STXML::SalsaTigerSentence.new(sent_string)

            # remove old semantics
            sent.remove_semantics

            if recorded_results and recorded_results[sent.id]
              recorded_results[sent.id].each { |target_ids, sense, lemma, pos|

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
            outfile.puts sent.get

          } # each sentence of file

          # write footer
          outfile.puts infile.tail
          outfile.close
          tempfile.close(true)
        } # each SalsaTiger file of the input directory
      end
    end
  end
end
