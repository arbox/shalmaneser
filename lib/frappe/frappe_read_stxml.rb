############################################3
# Class FrprepReadStxml
#
# given a STXML file,
# yield each of its sentences
class FrprepReadStxml
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
  def each_sentence(dummy)
    # read corresponding tab file?
    tab_sents = Array.new()
    if File.exists? @tabfilename
      tabfile = FNTabFormatFile.new(@tabfilename,@pos_suffix,@lemma_suffix)
      tabfile.each_sentence { |tabsent|
        tab_sents << tabsent
      }
    end

    # read STXML file
    infile = FilePartsParser.new(@stxmlfilename)
    index = 0
    infile.scan_s { |sent_string|
      sent = SalsaTigerSentence.new(sent_string)
      yield [sent, tab_sents.at(index), SynInterfaceSTXML.standard_mapping(sent, tab_sents.at(index))]
      index += 1
    }
  end
end
