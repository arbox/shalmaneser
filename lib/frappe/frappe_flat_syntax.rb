require 'tabular_format/fn_tab_format_file'
require 'salsa_tiger_xml/salsa_tiger_sentence'
require 'salsa_tiger_xml/salsa_tiger_xml_helper'

require_relative 'syn_interface_stxml'

############################################
# Class FrprepFlatSyntax:
#
# given a FNTabFormat file,
# yield each of its sentences in SalsaTigerXML,
# constructing a flat syntax
class FrprepFlatSyntax
  def initialize(tabfilename, # string: name of tab file
                 postag_suffix, # postag file suffix (or nil)
                 lemma_suffix)  # lemmatisation file suffix (or nil)

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

    # read tab file with lemma and POS info
    tabfile = FNTabFormatFile.new(@tabfilename, @pos_suffix, @lemma_suffix)

    tabfile.each_sentence() { |tabsent|
      # start new, empty sentence with "failed" attribute (i.e. no parse)
      # and with the ID of the corresponding TabFormat sentence
      sentid = tabsent.get_sent_id()
      if sentid.nil? or sentid =~ /^-*$/
        $stderr.puts "No sentence ID for sentence:"
        tabsent.each_line_parsed { |l| $stderr.print l.get("word"), " "}
        $stderr.puts
        # @todo AB: [2015-12-16 Wed 18:24]
        #   Change this!!!
        sentid = Time.new().to_f.to_s
      end
      sent = SalsaTigerSentence.new("<s id=\"#{SalsaTigerXMLHelper.escape(sentid)}\" failed=\"true\"></s>")

      # add single nonterminal node, category "S"
      single_nonterminal_id = SalsaTigerXMLHelper.escape(sentid.to_s + "_NT")
      vroot = sent.add_syn("nt", "S", # category
                           nil,  # word
                           nil,  # pos
                           single_nonterminal_id)

      # add terminals
      tabsent.each_line_parsed() { |line_obj|
        # make terminal node with tab sent info
        node_id = sentid.to_s + "_" + line_obj.get("lineno").to_s
        word = line_obj.get("word")
        unless word
          word = ""
        end
        word = SalsaTigerXMLHelper.escape(word)
        pos = line_obj.get("pos")
        unless pos
          pos = ""
        end
        pos = SalsaTigerXMLHelper.escape(pos)
        terminal = sent.add_syn("t", nil, # category
                                word, pos,
                                node_id)

        if line_obj.get("lemma")
          # lemma
          terminal.set_attribute("lemma", SalsaTigerXMLHelper.escape(line_obj.get("lemma")))
        end

        # add new terminal as child of vroot
        vroot.add_child(terminal, nil)
        terminal.add_parent(vroot, nil)
      } # each line of tab file

      # yield newly constructed SalsaTigerXMl sentence plus tab sentence
      yield [sent, tabsent, SynInterfaceSTXML.standard_mapping(sent, tabsent)]
    }
  end
end
