require "tempfile"
require 'fileutils'
require 'fred/targets'
require 'fred/fred_conventions' # !!
require 'fred/fred_error'

require 'logging'

module Shalmaneser
  module Fred
    # splitting package for WSD:
    # compute a split for feature files (one item a line, CSV),
    # and apply pre-computed split
    # to produce new feature files accordingly
    class FredSplitPkg
      ###
      # remove an old split
      # @param [FredConfigData] exp object
      # @param [String] split_id
      def self.remove_split(exp, split_id)
        begin
          # split_dir = FredSplitPkg.split_dir(exp, split_id, "new")
          split_dir = ::Shalmaneser::Fred.fred_dirname(exp, 'split', split_id, 'new')
        rescue
          # no split to be removed
          return
        end

        FileUtils.rm_rf(split_dir)
      end

      def initialize(exp)
        @exp = exp
      end

      # make a new split
      def make_new_split(split_id,  # string: ID
                         trainpercent, # float: percentage training data
                         ignore_unambiguous = false)

        # where to store the split?
        split_dir = split_dir(@exp, split_id, "new")

        lemmas_and_senses = Targets.new(@exp, nil, "r")
        unless lemmas_and_senses.targets_okay
          # error during initialization
          raise FredError, "FredSplitPkg: Error: Could not read list of known targets, bailing out."
        end

        # Iterate through lemmas,
        # split training feature files.
        #
        # Do the split only once per lemma,
        # even if we have sense-specific feature files
        feature_dir = ::Shalmaneser::Fred.fred_dirname(@exp, "train", "features")

        lemmas_and_senses.get_lemmas.each { |lemma|
          # construct split file
          splitfilename = split_dir + fred_split_filename(lemma)
          begin
            splitfile = File.new(splitfilename, "w")
          rescue
            raise "Error: Couldn't write to file " + splitfilename
          end

          # find lemma-specific  feature file

          filename = feature_dir + ::Shalmaneser::Fred.fred_feature_filename(lemma)

          unless File.exist?(filename)
            # try lemma+sense-specific feature file
            file_pattern = ::Shalmaneser::Fred.fred_feature_filename(lemma, "*", true)
            filename = Dir[feature_dir + file_pattern].first

            unless filename
              # no lemma+sense-specific feature file
              LOGGER.warn "Warning: split: no feature file found for #{lemma}, skipping."
              splitfile.close
              next
            end
          end

          # open feature file for reading
          begin
            file = File.new(filename)
          rescue
            raise "Couldn't read feature file " + filename
          end

          if ignore_unambiguous and
            lemmas_and_senses.get_senses(lemma).length < 2
            # unambiguous: ignore

            while file.gets
              splitfile.puts "ignore"
            end

          else
            # read from feature file, classify at random
            # as train or test,
            # write result to splitfile

            while file.gets
              if rand < trainpercent
                splitfile.puts "train"
              else
                splitfile.puts "test"
              end
            end
          end

          splitfile.close
        }
      end

      # change feature files according to
      # pre-computed split
      #
      #
      # returns: tempfile containing featurized items,
      # according to split,
      # or nil if the split file wouldn't contain any data
      def apply_split(filename, # feature file
                      lemma,    # string: lemma that filename is about
                      dataset,  # string: train, test
                      split_id) # string: split ID

        split_filename = split_dir(@exp, split_id) + fred_split_filename(lemma)

        # read feature file and split file at the same time
        # write to tempfile.
        f_feat = File.new(filename)
        f_split = File.new(split_filename)
        f_out = Tempfile.new("fred_split")

        num_yes = 0

        f_feat.each do |line|
          begin
            split_part = f_split.readline.chomp
          rescue
            $stderr.puts "FredSplit error: split file too short."
            $stderr.puts "skipping rest of featurization data."
            $stderr.puts "Split file: #{split_filename}"
            $stderr.puts "Feature file: #{filename}"
            # @todo AB: FIXME
            raise "HIER"

            f_out.close
            if num_yes > 0
              return f_out
            else
              return nil
            end
          end

          if split_part == dataset
            # write training data, and this item is in the training
            # part of the split,
            # or write test data, and item is in test part
            f_out.puts line
            num_yes += 1
          end
        end

        f_out.close
        f_feat.close
        f_split.close

        if num_yes > 0
          return f_out
        else
          return nil
        end

      end

      private

      def fred_split_filename(lemma)
        "fred.split.#{lemma}"
      end

      def split_dir(exp, split_id, mode = "existing")
        ::Shalmaneser::Fred.fred_dirname(exp, "split", split_id, mode)
      end
    end
  end
end
