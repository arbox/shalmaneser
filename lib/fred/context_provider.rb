require 'fred/abstract_context_provider'
require 'salsa_tiger_xml/salsa_tiger_sentence'
require 'salsa_tiger_xml/file_parts_parser'

module Shalmaneser
  module Fred

    ####################################
    # ContextProvider:
    # subclass of AbstractContextProvider
    # that assumes that the input text is a contiguous text
    # and computes the context accordingly.
    class ContextProvider < AbstractContextProvider
      ###
      # each_window: iterator
      #
      # given a directory with Salsa/Tiger XML data,
      # iterate through the data,
      # yielding each target word as soon as its context window is filled
      # (or the last file is at an end)
      def each_window(dir) # string: directory containing Salsa/Tiger XML data

        # iterate through files in the directory.
        # Try sorting filenames numerically, since this is
        # what frprep mostly does with filenames
        Dir[dir + "*.xml"].sort { |a, b|
          File.basename(a, ".xml").to_i <=> File.basename(b, ".xml").to_i
        }.each do |filename|
          # progress bar
          if @exp.get("verbose")
            $stderr.puts "Featurizing #{File.basename(filename)}"
          end
          f = STXML::FilePartsParser.new(filename)
          each_window_for_file(f) { |result| yield result }
        end
        # and empty the context array
        each_remaining_target { |result| yield result }
      end

      ##################################
      protected

      ######################
      # each_window_for_file: iterator
      # same as each_window, but only for a single file
      # (to be called from each_window())
      def each_window_for_file(fpp) # FilePartsParser object: Salsa/Tiger XMl data
        fpp.scan_s { |sent_string|
          sent = STXML::SalsaTigerSentence.new(sent_string)
          each_window_for_sent(sent) { |result| yield result }
        }
      end
    end
  end
end
