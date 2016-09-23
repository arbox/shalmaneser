require 'fred/fred_split_pkg'
require 'fred/FredConventions'

module Shalmaneser
  module Fred
    ########################################
    # read and write access to answer key files
    # manages a single answer key file for a given lemma/POS pair
    class AnswerKeyAccess
      ###
      def initialize(exp,      # experiment file object
                     dataset,  # "train", "test"
                     lemmapos, # lemma + POS (one string)
                     mode,     # "r", "w", "a"
                     split_id = nil,
                     split_dataset = nil)
        unless ["r", "w", "a"].include? mode
          $stderr.puts "FredFeatures error: AnswerKeyAccess initialized with mode #{mode}."
          exit 1
        end

        @mode = mode

        answer_filename = ::Shalmaneser::Fred.fred_dirname(exp, dataset, "keys", "new") + fred_answerkey_filename(lemmapos)

        # are we reading the whole answer key file, or only the test part
        # of a split of it?
        if split_id
          # we are accessing part of a split
          # we can only do that when reading!
          unless @mode == "r"
            $stderr.puts "AnswerKeyAccess error: cannot access split answer file in write mode."
            exit 1
          end

          # apply_split returns a closed temporary file
          split_obj = FredSplitPkg.new(exp)
          @f = split_obj.apply_split(answer_filename, lemmapos, split_dataset, split_id)
          if @f.nil?
            # the split_dataset part of the split doesn't contain any data
            $stderr.puts "Warning: no #{split_dataset} data for lemma #{lemmapos}"
          else
            @f.open
          end

        else
          # we are reading the whole thing
          begin
            @f = File.new(answer_filename, @mode)
          rescue
            @f = nil
          end
        end
      end

      ###
      def write_line(lemma,     # string: lemma
                     pos,       # string: POS
                     ids,       # array:string: target IDs
                     sid,       # string: sentence ID
                     senses,    # array:string: senses
                     senses_this_item) # array:string: senses for this item
        unless ["w", "a"].include? @mode
          $stderr.puts "FredFeatures error: AnswerKeyAccess: cannot write in read mode."
          exit 1
        end
        unless @f
          raise "Shouldn't be here"
        end

        # write answer key:
        # lemma POS ID senses
        if senses.include? nil or senses.include? ""
          raise "empty sense"
        end
        if senses_this_item.include? nil or senses_this_item.include? ""
          raise "empty sense for this item"
        end

        senses_s = senses.map { |s| s.gsub(/,/, "COMMA")}.join(",")
        senses_ti_s = senses_this_item.map { |s|
          s.gsub(/,/, "COMMA")}.join(",")
        id_s = ids.map { |i| i.gsub(/:/, "COLON") }.join("::")

        @f.puts "#{lemma} #{pos} #{id_s} #{sid} #{senses_s} #{senses_ti_s}"
      end

      ###
      # yield one line at a time:
      # tuple (lemma, POS, ids, sentence_ID, all_assigned_senses, transformed_senses_for_this_item)
      def each
        unless @mode == "r"
          $stderr.puts "FredFeatures error: AnsewrKeyAccess: cannot read in write mode"
        end
        unless @f
          # something went wrong during initialization:
          # split didn't contain data
          return
        end

        @f.each { |line|

          lemma, pos, id_s, sid, senses_s, senses_this_item_s = line.split
          ids = id_s.split("::").map { |i| i.gsub(/COLON/, ":") }
          senses = senses_s.split(",").map { |s| s.gsub(/COMMA/, ",") }

          senses_this_item = senses_this_item_s.split(",").map { |s|
            s.gsub(/COMMA/, ",") }

          yield [lemma, pos, ids, sid, senses, senses_this_item]
        }
      end

      ###
      def close
        @f.close
      end

      ###
      def AnswerKeyAccess.remove_files(exp, dataset)
        Dir[::Shalmaneser::Fred.fred_dirname(exp, dataset, "keys", "new") + fred_answerkey_filename("*")].each { |filename|
          if File.exists?(filename)
            File.delete(filename)
          end
        }
      end

      ####
      # filename for answer key files
      # @note Used only in FredFeatures.
      # @note Imported from FredConventions.
      def fred_answerkey_filename(lemma)
        return "fred.answerkey.#{lemma}"
      end
    end
  end
end
