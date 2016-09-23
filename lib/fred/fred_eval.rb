# FredEval
# Katrin Erk April 05
#
# Frame disambiguation system: evaluate classification results
#
# While the other main classes of Fred just provide a new() method
# and a compute() method,
# the FredEval class also provides access methods to all the
# individual evaluation results and allows for a flag that
# suppresses evaluation output to a file --
# such that this package can also be used by external systems that
# wish to evaluate Fred.
#
# Inherits from the Eval class that is not Fred-specific

# Salsa packages
require 'eval'
require "ruby_class_extensions"

# Fred packages
require 'fred/fred_conventions' # !!
require 'fred/answer_key_access'
require 'fred/targets'

module Shalmaneser
  module Fred
    class FredEval < Eval

      ###
      # new
      #
      # evaluate runtime options and announce the task
      def initialize(exp_obj, # FredConfigData object
                     options) # hash: runtime option name (string) => value(string)

        @exp = exp_obj

        ###
        # evaluate runtime options
        @split_id = nil
        logfilename = nil

        options.each_pair { |opt, arg|
          case opt
          when "--logID"

            @split_id = arg
          when "--printLog"
            logfilename = ::Shalmaneser::Fred.fred_dirname(@exp, "eval", "log", "new") +
                          "eval_logfile.txt"

          else
            # case of unknown arguments has been dealt with by fred.rb
          end
        }

        ###
        # make outfile name
        outfilename =  ::Shalmaneser::Fred.fred_dirname(@exp, "eval", "eval", "new") +
                       "eval.txt"

        ###
        # do we regard all senses as assigned,
        # as long as they surpass some threshold?
        # if we are doing multilabel evaluation, we need the full list of senses
        @threshold = @exp.get("assignment_confidence_threshold")
        @target_obj = Targets.new(@exp, nil, "r")
        unless @target_obj.targets_okay
          # error during initialization
          $stderr.puts "FredEval: Error: Could not read list of known targets, bailing out."
          exit 1
        end

        if @threshold or @exp.get("handle_multilabel") == "keep"
          @multiple_senses_assigned = true
        else
          @multiple_senses_assigned = false
        end


        ###
        # initialize abstract class behind me
        if @multiple_senses_assigned
          # we are possibly assigning more than one sense: do precision/recall
          # instead of accuracy:
          # "true" is what "this sense has been assigned" is mapped to below.
          super(outfilename, logfilename, "true")
        else
          super(outfilename, logfilename)
        end

        # what is being done with instances with multiple sense labels?
        @handle_multilabel = @exp.get("handle_multilabel")

        ###
        # announce the task
        $stderr.puts "---------"
        $stderr.print "Fred  experiment #{@exp.get("experiment_ID")}: Evaluating classifiers"
        if @split_dir
          $stderr.puts " using split with ID #{@split_id}"
        else
          $stderr.puts
        end
        if @multiple_senses_assigned
          $stderr.puts "Allowing for the assignment of multiple senses,"
          $stderr.puts "computing precision and recall against the full sense list of a lemma."
        end
        $stderr.puts "Writing result to #{::Shalmaneser::Fred.fred_dirname(@exp, "eval", "eval")}"
        $stderr.puts "---------"
      end

      #####
      protected

      ###
      # each_group
      #
      # yield each group name in turn
      # in our case, group names are lemmas
      #
      # also, set object-global variables in such a way
      # that the elements of this group can be read
      def each_group

        # access to classifier output files
        output_dir = ::Shalmaneser::Fred.fred_dirname(@exp, "output", "tab")
        # access to answer key files

        if @split_id
          # make split object and parameter hash to pass to it
          dataset = "train"
        else
          dataset = "test"
        end

        # iterate through instance files
        @target_obj.get_lemmas.sort.each { |lemma|
          # progress report
          if @exp.get("verbose")
            $stderr.puts "Evaluating " + lemma
          end

          # file with classification results
          begin
            @classfile = File.new(output_dir + ::Shalmaneser::Fred.fred_result_filename(lemma))
          rescue
            # no classification results
            @classfile = nil
          end

          # file with answers:
          # maybe we need to apply a split first
          if @split_id
            @goldreader = AnswerKeyAccess.new(@exp, "train", lemma, "r", @split_id, "test")
          else
            @goldreader = AnswerKeyAccess.new(@exp, "test", lemma, "r")
          end

          # doing multilabel evaluation?
          # then we need a list of all senses
          if @multiple_senses_assigned
            @all_senses = @target_obj.get_senses(lemma)
          else
            @all_senses = nil
          end

          yield lemma
        }
      end

      ###
      # each_instance
      #
      # given a lemma name, yield each instance of this lemma in turn,
      # or rather: yield pairs [gold_class(string), assigned_class(string)]
      #
      # relies on each_group() having set the appropriate readers
      # <@goldreader> and <@classfile>
      def each_instance(lemma) # string: lemma name
        # watch out for repeated instances
        # which may occur if handle_multilabel = repeat.
        # Only yield them once to avoid re-evaluating multi-label instances
        #
        # instance_ids_seen: hash target_ids -> true/nil
        instance_ids_seen = {}

        # read gold file and classifier output file in parallel
        @goldreader.each { |lemma, pos, target_ids, sid, senses_gold, transformed_gold_senses|

          # classline: format
          # (label confidence)*
          # such that the label with the highest confidence is first
          classline = nil
          if @classfile
            classline = @classfile.gets
          end
          if classline.nil?
            classline = ""
          end

          # $stderr.puts "HIER0 #{classline} #{@classfile.nil?}"

          # have we done this same instance previously?
          if instance_ids_seen[target_ids]
            next
          end
          # instance not seen previously, but mark as seen now.
          instance_ids_seen[target_ids] = true

          # determine all assigned senses and their confidence levels
          # determine all sense/confidence pairs
          # senses assigned: list of pairs [senselist, confidence]
          # where senselist is an array of sense strings
          senses_assigned = []
          current_sense = nil

          classline.split.each_with_index { |entry, index|
            if index % 2 == 0
              # we have a sense label
              if @handle_multilabel == "join"
                # split up joined senses
                current_sense = ::Shalmaneser::Fred.fred_split_sense(entry)
              else
                current_sense = [entry]
              end

            else
              # we have a confidence level
              senses_assigned << [current_sense, entry.to_f]
            end
          }


          if @threshold
            # multiple senses assigned, and
            # regard as assigned everything above a given threshold

            # transform senses_assigned:
            # in the case of "join", one sense may have several confidence levels,
            # one on its own and one in a joined sense
            senses_assigned_hash = {}
            senses_assigned.each { |senses, confidence|
              senses.each { |s|
                # assign to each sense the maximum of its previous confidence
                # and this one.
                # watch out: confidence may be smaller than zero
                if senses_assigned_hash[s]
                  senses_assigned_hash[s] = [senses_assigned_hash[s], confidence].max
                else
                  senses_assigned_hash[s] = confidence
                end
              }
            }

            # select all sense/confidence pairs where confidence is above threshold
            senses_assigned = senses_assigned_hash.to_a.select { |sense, confidence|
              confidence >= @threshold
            }.map { |sense, confidence|
              # then retain only the sense, not the confidence
              sense
            }

            unless @all_senses
              raise "Shouldn't be here"
            end

            # for each sense out of the list of all senses:
            # yield a pair of [applies, has been assigned]
            # both 'applies' and 'has been assigned' will be
            # a string of either 'true' or 'false'
            # assignment is accurate if both are the same
            @all_senses.each { |sense_of_lemma|
              gold_class = (senses_gold.include? sense_of_lemma).to_s
              assigned_class = (senses_assigned.include? sense_of_lemma).to_s
              yield [gold_class, assigned_class]
            }
          else
            # regard only one sense as assigned at a time
            # count as correct if the list of gold classes
            # contains the main assigned class
            # (relatively lenient evaluation)

            # actually assigned class: only the one with the
            # maximum confidence
            # $stderr.puts "HIER5 #{senses_assigned.length()}"
            if senses_assigned.empty?
            # nothing to yield
            else
              max_senselist = senses_assigned.max { |a, b|
                a.last <=> b.last
              }.first

              max_senselist.each { |single_sense|
                gold_class = (senses_gold.include? single_sense).to_s
                yield [gold_class, "true"]
              }
            end
          end
        }
      end

      private

      # @note Used only in FredEval.
      # @note Imported from FredConventions
      def fred_split_sense(joined_senses)
        joined_senses.split("++")
      end
    end
  end
end
