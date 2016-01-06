require 'fred/abstract_context_provider'
require 'tabular_format/tab_format_sentence'
require 'salsa_tiger_xml/salsa_tiger_sentence'
require 'salsa_tiger_xml/file_parts_parser'

module Shalmaneser
  module Fred
    ####################################
    # SingleSentContextProvider:
    # subclass of AbstractContextProvider
    # that assumes that each sentence of the input text
    # stands on its own
    class SingleSentContextProvider < AbstractContextProvider
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
        }.each { |filename|
          # progress bar
          if @exp.get("verbose")
            $stderr.puts "Featurizing #{File.basename(filename)}"
          end
          f = STXML::FilePartsParser.new(filename)
          each_window_for_file(f) { |result|
            yield result
          }
        }
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

          each_window_for_sent(sent) { |result|
            yield result
          }
        }
        # no need to clear the context: we're doing this after each sentence
      end

      ###
      # each_window_for_sent: empty context after each sentence
      def each_window_for_sent(sent)
        if sent.is_a? STXML::SalsaTigerSentence
          each_window_for_stsent(sent) { |result| yield result }

        elsif sent.is_a? TabFormatSentence
          each_window_for_tabsent(sent) { |result | yield result }

        else
          $stderr.puts "Error: got #{sent.class}, expected SalsaTigerSentence or TabFormatSentence."
          exit 1
        end

        # clear the context
        each_remaining_target { |result| yield result }
      end
    end
  end
end
