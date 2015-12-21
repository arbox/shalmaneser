require_relative 'syn_interface'

require 'tabular_format/fn_tab_format_file'

#############################
# abstract class, to be inherited:
#
# tabular format interface for modules
# offering POS tagging, lemmatization etc.
module Shalmaneser
  module Frappe
    class SynInterfaceTab < SynInterface

      ##########
      protected

      # fntab_words_for_file:
      # given a file in tab format, columns as in FNTabFormat,
      # get the "word" entries and write them to a given file,
      # one word per line, as input for processing
      def SynInterfaceTab.fntab_words_to_file(infilename, # string: name of input file
                                              outfile,    # stream: output file
                                              sent_marker = "", # string: mark end of sentence how?
                                              iso = nil)  # non-nil: assume utf-8, transform to iso-8859-1
        corpusfile = FNTabFormatFile.new(infilename)
        corpusfile.each_sentence {|s|
          s.each_line_parsed {|line_obj|
            if iso
              outfile.puts UtfIso.to_iso_8859_1(line_obj.get("word"))
            else
              outfile.puts line_obj.get("word")
            end
          }
          outfile.puts sent_marker
        }
      end
    end
  end
end
