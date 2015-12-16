# -*- encoding: utf-8 -*-
# AB, 2010-11-25


##############################
# class for managing the parses of one file
class OneParsedFile
  attr_reader :filename

  def initialize(filename,   # string: core of filename for the parse file
		 complete_filename, # string: complete filename of parse file
		 obj_with_iterator) # object with each_sentence method, see above
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
