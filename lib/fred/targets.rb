require "fred/file_zipped"
require 'fred/FredConventions' # !

module Shalmaneser
  module Fred
    class Targets
      attr_reader :targets_okay

      ###
      def initialize(exp,                 # experiment file object
                     interpreter_class,   # SynInterpreter class, or nil
                     mode)                # string: "r", "w", "a", as in files
        @exp = exp
        @interpreter_class = interpreter_class

        # keep recorded targets here.
        # try to read old list now.
        @targets = {}

        # write target info in the classifier directory.
        # This is _not_ dependent on a potential split ID
        @dir = File.new_dir(::Shalmaneser::Fred.fred_classifier_directory(@exp), "targets")

        @targets_okay = true
        case mode
        when "w"
        # start from scratch, no list of targets
        when "a", "r"
          # read existing file containing targets
          begin
            file = FileZipped.new(@dir + "targets.txt.gz")
          rescue
            # no pickle present: signal this
            @targets_okay = false
            return
          end
          file.each { |line|
            line.chomp!
            if line =~ /^LEMMA (.+) SENSES (.+)$/
              lemmapos = $1
              senses = $2.split
              lemmapos.gsub!(/ /, '_')
              #lemmapos.gsub!(/\.[A-Z]\./, '.')
              @targets[lemmapos] = senses
            end
          }

        else
          $stderr.puts "Error: shouldn't be here."
          exit 1
        end

        if ["w", "a"].include? mode
          @record_targets = true
        else
          @record_targets = false
        end
      end

      ###
      # determine_targets:
      # for a given SalsaTigerSentence,
      # determine all targets,
      # each as a _single_ main terminal node
      #
      # We need a single terminal node in order
      # to compute the context window
      #
      # returns:
      #  hash: target_IDs -> list of senses
      #   where target_IDs is a pair [list of terminal IDs, main terminal ID]
      #
      #  where a sense is represented as a hash:
      #  "sense": sense, a string
      #  "obj":   FrameNode object
      #  "all_targets": list of node IDs, may comprise more than a single node
      #  "lex":   lemma, or multiword expression in canonical form
      #  "sid": sentence ID
      def determine_targets(sent)
        raise "overwrite me"
      end

      ##
      # returns a list of lemma-pos combined strings
      def get_lemmas
        return @targets.keys
      end

      ##
      # access to lemmas and POS, returns a list of pairs [lemma, pos] (string*string)
      def get_lemma_pos
        @targets.keys.map { |lemmapos| fred_lemmapos_separate(lemmapos) }
      end

      ##
      # access to senses
      def get_senses(lemmapos) # string, result of fred_lemmapos_combine
        @targets[lemmapos] ? @targets[lemmapos] : []
      end

      ##
      # write file
      def done_reading_targets
        begin
          file = FileZipped.new(@dir + "targets.txt.gz", "w")
        rescue
          $stderr.puts "Error: Could not write file #{@dir}targets.txt.gz"
          exit 1
        end

        @targets.each_pair { |lemma, senses|
          file.puts "LEMMA #{lemma} SENSES "+ senses.join(" ")
        }

        file.close
      end

      ###
      # @param lemmapos [String]
      # @note Used only in FredDetermineTargets.
      # fred_lemmapos_separate: take one string, return two strings
      #      if no POS could be retrieved, returns nil as POS and the whole string as lemma
      # @note Imported from FredConventions.
      def fred_lemmapos_separate(lemmapos)
        pieces = lemmapos.split(".")

        if pieces.length > 1
          return [pieces[0..-2].join("."), pieces[-1]]
        else
          # no POS found, treat all of lemmapos as lemma
          return [lemmapos, nil]
        end
      end

      ###############################
      protected

      ##
      # record: record occurrence of a lemma/sense pair
      # <@targets> data structure
      def record(target_info)
        lemmapos = ::Shalmaneser::Fred.fred_lemmapos_combine(target_info["lex"], target_info["pos"])
        unless @targets[lemmapos]
          @targets[lemmapos] = []
        end

        unless @targets[lemmapos].include? target_info["sense"]
          @targets[lemmapos] << target_info["sense"]
        end
      end
    end
  end
end
