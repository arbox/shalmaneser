# -*- encoding: utf-8 -*-
# AB, 2010-11-25

##############################
# class for managing the parses of one file
module Shalmaneser
  module Frappe
    class OneParsedFile
      attr_reader :filename
      # @param [String] filename  The core of filename for the parse file.
      # @param [String] complete_filename The complete filename of the parse file.
      # @param [Enumerable] obj_with_iterator object with each_sentence method, see above
      def initialize(filename, complete_filename, obj_with_iterator)
        @obj_with_iterator = obj_with_iterator
        @filename = filename
        @complete_filename = complete_filename
      end

      # yield each parse sentence as a tuple
      # [ salsa/tiger xml sentence, tab format sentence, mapping]
      # of a SalsaTigerSentence object, a FNTabSentence object,
      # and a hash: FNTab sentence lineno(integer) -> array:SynNode
      # pointing each tab word to one or more SalsaTigerSentence terminals
      def each_sentence
        @obj_with_iterator.each_sentence(@complete_filename) { |st_sent, tab_sent, mapping|
          yield [st_sent, tab_sent, mapping]
        }
      end
    end
  end
end
