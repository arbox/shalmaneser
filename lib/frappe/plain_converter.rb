require 'tokenizer'
require 'tabular_format/fn_tab_format_file'

module Shalmaneser
  module Frappe
    # A converter from plain text to Salsa Tab Format.
    # Performs tokenization.
    class PlainConverter
      def initialize
        # suffixes for different types of output files
        @file_suffixes = {"lemma" => ".lemma", "pos" => ".pos", "tab" => ".tab", "stxml" => ".xml"}
      end

      ###############
      # transform_plain:
      #
      # transformation for plaintext:
      #
      # transform to Tab format, separating punctuation from adjacent words
      # @param input_dir [String] input directory
      # @param output_dir [String] output directory
      def transform_plain_dir(input_dir, output_dir)
        Dir[input_dir + "*"].each do |plainfilename|
          # open input and output file
          # end output file name in "tab" because that is, at the moment, required
          outfilename = output_dir + File.basename(plainfilename, '.*') + @file_suffixes["tab"]
          plain_to_tab_file(plainfilename, outfilename)
        end
      end

      ####
      # transform plaintext file to Tab format file
      # @param [String] input_filename string: name of input file
      # @param [String] output_filename string: name of output file
      def plain_to_tab_file(input_filename, output_filename)
        sentences = File.open(input_filename) do |f|
          # The file is supposed to contain one sentence per line.
          f.readlines.map(&:chomp).map(&:strip).reject(&:empty?)
        end
        id = File.basename(input_filename, '.*')
        t = Tokenizer::Tokenizer.new
        File.open(output_filename, "w") do |f|
          sentences.each_with_index do |sentence, idx|
            # byebug
            sentid = "#{id}_#{idx}"
            sentence = t.tokenize(sentence)
            sentence.each do |word|
              # for each word, one line, entries in the line tab-separated
              # the 'word' entry is the word, the 'lu_sent_ids' entry is the sentence ID sentid,
              # all other entries (gf, pt, frame etc.) are not set
              f.puts FNTabFormatFile.format_str("word" => word, "sent_id" => sentid)
            end
            f.puts
          end
        end
      end
    end
  end
end
