require_relative 'syn_interface_stxml'
require 'tabular_format/fn_tab_format_file'
require 'salsa_tiger_xml/salsa_tiger_sentence'
require 'salsa_tiger_xml/file_parts_parser'

#
# given a STXML file,
# yield each of its sentences
module Shalmaneser
  module Frappe
    class FrappeReadStxml
      def initialize(stxmlfilename, # string: name of SalsaTigerXML file
                     tabfilename,   # string: name of corresponding tab file (or nil)
                     postag_suffix,    #  POS tag file suffix (or nil)
                     lemma_suffix)     #  lemmatization file suffix (or nil)

        @stxmlfilename = stxmlfilename
        @tabfilename = tabfilename
        @pos_suffix = postag_suffix
        @lemma_suffix = lemma_suffix
      end
      # yield each non-parse sentence as a tuple
      # [ salsa/tiger xml sentence, tab format sentence, mapping]
      # of a SalsaTigerSentence object, a FNTabSentence object,
      # and a hash: FNTab sentence lineno(integer) -> array:SynNode
      # pointing each tab word to one or more SalsaTigerSentence terminals
      # @todo AB: [2015-12-17 Thu 20:22]
      #   Remove this dummy argument.
      def each_sentence(dummy)
        # read corresponding tab file?
        tab_sents = []
        if File.exist?(@tabfilename)
          tabfile = FNTabFormatFile.new(@tabfilename, @pos_suffix, @lemma_suffix)
          tabfile.each_sentence { |tabsent| tab_sents << tabsent }
        end

        # read STXML file
        infile = FilePartsParser.new(@stxmlfilename)
        index = 0
        infile.scan_s do |sent_string|
          sent = SalsaTigerSentence.new(sent_string)
          yield [sent, tab_sents.at(index), SynInterfaceSTXML.standard_mapping(sent, tab_sents.at(index))]
          index += 1
        end
      end
    end
  end
end
