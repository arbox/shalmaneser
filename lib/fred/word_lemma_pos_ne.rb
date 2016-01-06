require 'salsa_tiger_xml/salsa_tiger_xml_helper'

########################################
# given a SynNode object representing a terminal,
# return:
# - the word
# - the lemma
# - the part of speech
# - the named entity (if any)
#
# as a tuple
#
# WARNING: word and lemma are turned to lowercase
module Shalmaneser
module Fred
module WordLemmaPosNe
  # @param syn_obj [SynNode]
  # @param i [SynInterpreter]
  def word_lemma_pos_ne(syn_obj, i)
    unless syn_obj.is_terminal?
      $stderr.puts "Featurization warning: unexpectedly received non-terminal"
      return [nil, nil, nil, nil]
    end

    word = syn_obj.word
    if word
      word.downcase!
    end

    lemma = i.lemma_backoff(syn_obj)
    if lemma and STXML::SalsaTigerXMLHelper.unescape(lemma) == "<unknown>"
      lemma = nil
    end

    if lemma
      lemma.downcase!
    end

    pos = syn_obj.part_of_speech

    ne = syn_obj.get_attribute("ne")

    unless ne
      ne = syn_obj.get_attribute("headof_ne")
    end

    [word, lemma, pos, ne]
  end
end
end
end
