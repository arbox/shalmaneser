# Baseline
# Katrin Erk April 05
#
# baseline for WSD:
# always assign most frequent sense
# The baseline doesn't do binary classifiers.

require 'fred/FredConventions' # !
require 'fred/fred_split_pkg'
require "fred/FredFeatures"
require 'fred/targets'
require 'fred/fred_error'
require 'logging'

module Shalmaneser
  module Fred
    class Baseline
      ###
      # new
      #
      # get splitlog dir (if any) along with everything else
      # because we are only evaluating the training data
      # at test time
      #
      def initialize(exp, # FredConfigData object
                     split_id = nil) # string: split ID
        @exp = exp
        @split_id = split_id

        # for each lemma: remember prevalent sense
        @lemma_to_sense = {}

        if @split_id
          split_obj = FredSplitPkg.new(@exp)
        end

        lemma_done = {}

        # iterate through lemmas
        @target_obj = Targets.new(@exp, nil, "r")

        unless @target_obj.targets_okay
          # error during initialization
          raise FredError, "Baseline: Error: Could not read list of known targets, bailing out."
        end

        @target_obj.get_lemmas.each do |lemmapos|
          if @split_id
            # read training split of answer keys
            answer_obj = AnswerKeyAccess.new(@exp, "train", lemmapos, "r", @split_id, "train")
          else
            # read full answer key file of training data
            answer_obj = AnswerKeyAccess.new(@exp, "train", lemmapos, "r")
          end

          count_senses = Hash.new(0)

          answer_obj.each do |_lemma, _pos, _ids, _sid, _senses_all, senses_this|
            # senses_this may include more than one sense for multi-label assignment
            senses_this.each { |sense| count_senses[sense] += 1 }
          end

          @lemma_to_sense[lemmapos] = count_senses.keys.max do |a, b|
            count_senses[a] <=> count_senses[b]
          end
        end

        @lemma = nil
      end

      ###
      # @todo DELETE IT!
      def train(infilename)
        # no training here
      end

      ###
      # @todo DELETE IT!
      def write(classifier_file)
        # no classifiers to write
      end

      # @todo AB: Nonsense method.
      def exists?(classifier_file)
        true
      end

      def read(classifier_file)
        values = ::Shalmaneser::Fred.deconstruct_fred_classifier_filename(File.basename(classifier_file))
        @lemma = values["lemma"]
        if @lemma
          return true
        else
          LOGGER.warn "Warning: couldn't determine lemma name in"\
                      " #{classifier_file}, skipping!"
          return false
        end
      end

      def read_resultfile(filename)
        retv = []
        begin
          f = File.new(filename)
        rescue
          raise FredError, "Could not read baseline result file #{filename}."
        end

        f.each { |line| retv << [[line.chomp, 1.0]] }

        retv
      end

      def apply(infilename, outfilename)
        # open input and output file
        begin
          out_f = File.new(outfilename, "w")
        rescue
          raise FredError, "Error: Cannot write to classification output file"\
                           " #{outfilename}."
        end

        begin
          f = File.new(infilename)
        rescue
          raise FredError, "Error: cannot read feature file #{infilename}."
        end

        # deconstruct input filename to determine lemma
        unless @lemma
          # something went wrong in read()
          return false
        end

        # do we have a sense for this?
        unless (sense = @lemma_to_sense[@lemma])
          # nope: assign "NONE" (or whatever the null label is here)
          sense = @exp.get("negsense")
          unless sense
            sense = "NONE"
          end
        end

        # @todo AB: This is a nonsense.
        f.each { |line| out_f.puts sense }

        out_f.close
        f.close

        true
      end
    end
  end
end
