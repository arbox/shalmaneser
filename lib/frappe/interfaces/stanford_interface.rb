#-*- coding: utf-8 -*-
# @author Andrei Beliankou
# @date> 2013-12-26

####
# sp 21 07 05
#
# modified ke 30 10 05: adapted to fit into SynInterface
#
# represents a file containing Stanford parses
#
# underlying data structure for individual sentences: SalsaTigerSentence

require_relative 'counter'

require 'salsa_tiger_xml/salsa_tiger_sentence'
require 'salsa_tiger_xml/salsa_tiger_xml_helper'
require 'tabular_format/fn_tab_format_file'

require "tempfile"
################################################
# Interface class
module Shalmaneser
  module Frappe
    class StanfordInterface < SynInterfaceSTXML
      LOGGER.debug 'Announcing Stanford Interface'
      StanfordInterface.announce_me

      def self.system
        'stanford'
      end

      def self.service
        'parser'
      end

      ###
      # initialize to set values for all subsequent processing
      # @param program_path [String] path to a system
      # @param insuffix [String] suffix of tab files
      # @param outsuffix [String] suffix of parsed files
      # @param stsuffix [String] suffix of Salsa/TigerXML files
      # @param var_hash [Hash] optional arguments
      def initialize(program_path, insuffix, outsuffix, stsuffix, var_hash = {})
        super

        # @todo This should be checked in the OptionParser.
        unless @program_path =~ /\/$/
          @program_path += '/'
        end

        # new: evaluate var hash
        @pos_suffix = var_hash["pos_suffix"]
        @lemma_suffix = var_hash["lemma_suffix"]
        @tab_dir = var_hash["tab_dir"]

        # sanity checks
        # AB: @todo Move this check to the invoker!
        unless @tab_dir
          raise "Need to set tab directory on initialization"
        end
      end

      ####
      # parse a directory with TabFormat files and write the parse trees to outputdir
      # I assume that the files in inputdir are smaller than
      # the maximum number of sentences that
      # Stanford can parse in one go (i.e. that they are split)
      #
      # @param in_dir [String] input directory name
      # @param out_dir [String] output directory name
      def process_dir(in_dir, out_dir)

        # We use the old paradigm for now: the parser binary is wrapped
        # into a shell script, we invoke this script.
        #stanford_prog = "#{@program_path}lexparser-german.sh"

        # Borrowed from <lexparser-german.sh>.
        tlp = 'edu.stanford.nlp.parser.lexparser.NegraPennTreebankParserParams'

        lang_opts = '-hMarkov 1 -vMarkov 2 -vSelSplitCutOff 300 -uwm 1 -unknownSuffixSize 2 -nodeCleanup 2'

        # grammar1 = 'edu/stanford/nlp/models/lexparser/germanPCFG.ser.gz'
        grammar2 = 'edu/stanford/nlp/models/lexparser/germanFactored.ser.gz'

        stanford_prog = %Q{
    java -cp "#{@program_path}*:" edu.stanford.nlp.parser.lexparser.LexicalizedParser -maxLength 100 \
    -tLPP #{tlp} #{lang_opts} -tokenized \
    -encoding UTF-8 \
    -outputFormat "oneline" \
    -outputFormatOptions "includePunctuationDependencies" \
    -loadFromSerializedFile #{grammar2} \
    }

        Dir[in_dir + "*" + @insuffix].each do |inputfilename|

          STDERR.puts "*** Parsing #{inputfilename} with StanfordParser."
          corpusfilename = File.basename(inputfilename, @insuffix)
          parsefilename = out_dir + corpusfilename + @outsuffix
          tempfile = Tempfile.new(corpusfilename)

          # we need neither lemmata nor POS tags; stanford can do with the words
          corpusfile = FNTabFormatFile.new(inputfilename, nil, nil)

          corpusfile.each_sentence do |sentence|
            #puts sentence
            tempfile.puts sentence
          end

          tempfile.close

          # Invoke the expternal parser.
          invocation_str = "#{stanford_prog} #{tempfile.path} > #{parsefilename} 2>/dev/null"
          STDERR.puts invocation_str

          Kernel.system(invocation_str)

        end
      end

      ###
      # for a given parsed file:
      # yield each sentence as a pair
      #  [SalsaTigerSentence object, FNTabFormatSentence object]
      # of the sentence in SalsaTigerXML and the matching tab format sentence
      #
      # If a parse has failed, returns
      #  [failed_sentence (flat SalsaTigerSentence), FNTabFormatSentence]
      # to allow more detailed accounting for failed parses
      # (basically just a flat structure with a failed=true attribute
      # at the sentence node)
      def each_sentence(parsefilename)

        # get matching tab file for this parser output file
        parsefile = File.new(parsefilename)
        tabfilename = @tab_dir + File.basename(parsefilename, @outsuffix) + @insuffix
        tabfile = FNTabFormatFile.new(tabfilename, @postag_suffix, @lemma_suffix)

        sentid = 0
        tabfile.each_sentence do |tab_sent| # iterate over corpus sentences

          # assemble next sentence in Stanford file by reading lines from parsefile
          # for stanford:
          while true
            sentence_str = parsefile.gets
            # Sentence contains a valid or an empty parse.
            # AB: @todo Investigate how does an empty parse look like.
            if sentence_str =~ /\(ROOT|TOP|PSEUDO/ or sentence_str =~ /^\(\(\)/
              sentid +=1
              break
            # There is no parse.
            elsif sentence_str.nil?
              raise "Error: premature end of parser file!"
            end
          end

          sentence_str.chomp!.gsub!(/\)\)/, ') )').gsub!(/\)\)/, ') )')

          # VAFIN_HD -> VAFIN-HD
          # for the current german grammar not really usefull
          #sentence_str.gsub!(/(\([A-Z]+)_/, '\1-')

          if tab_sent.get_sent_id == "--"
            my_sent_id = "#{File.basename(parsefilename, @outsuffix)}_#{sentid}"
          else
            my_sent_id = tab_sent.get_sent_id
          end

          st_sent = build_salsatiger(" " + sentence_str + " ", 0,
                                     [], Counter.new(0),
                                     Counter.new(500),
                                     SalsaTigerSentence.empty_sentence(my_sent_id.to_s))

          # AB: When is it possible?
          next unless st_sent

          yield [st_sent, tab_sent, StanfordInterface.standard_mapping(st_sent, tab_sent)]
        end

        # All TabFile sentences are consumed.
        # Now we may just encounter comments, garbage, empty lines etc.
        while abline = parsefile.gets
          case abline
          when /^%/, /^\s*$/
          # Found empty lines, comments, end of input indicate end of
          # current parse.
          # AB: TODO Investigate what can StanfordParser output.
          else
            # We found something meaningfull, a parse tree.
            raise "Error: Premature end of tab file! Found line: #{abline}"
          end
        end

        parsefile.close
      end # each_sentence


      ###
      # write Salsa/TIGER XML output to file
      # @param infilename [String] name of parse file
      # @param outfilename [String] name of output stxml file
      def to_stxml_file(infilename, outfilename)

        File.open(outfilename, 'w') do |outfile|
          outfile.puts STXML::SalsaTigerXMLHelper.get_header
          each_sentence(infilename) do |st_sent, tabsent|
            outfile.puts st_sent.get
          end
          outfile.puts STXML::SalsaTigerXMLHelper.get_footer
        end

      end



      ########################
      private

      ###
      # Recursive function for parsing a Stanford parse tree and
      # building a SalsaTigerSentence recursively
      #
      # Algorithm: manage stack which contains, for the current constituent,
      # child constituents (if a nonterminal), and the category label.
      # When the end of a constituent is reached, a new SynNode (TigerSalsa node) ist created.
      # All children and the category label are popped from the stack and integrated into the
      # TigerSalsa data structure. The new node is re-pushed onto the
      # stack.
      # @param sentence [String]
      # @param pos [Fixnum] position in string (index)
      # @param stack [Array] stack with incomplete nodes
      # @param termc [Counter] terminal counter
      # @param nontc [Counter] nonterminal counter
      # @param sent_obj [SalsaTigerSentence] SalsaTigerSentence
      def build_salsatiger(sentence, pos, stack, termc, nontc, sent_obj)

        if sentence =~ /\(\)/
          return nil
        end

        # main case distinction: match the beginning of our string
        # (i.e. what follows our current position in the string)
        case sentence[pos..-1]
        when /^ *$/ # nothing -> whole sentence parsed
          if stack.length == 1
            # sleepy always delivers one "top" node; if we don't get just one
            # node, something has gone wrong
            node = stack.pop
            node.del_attribute("gf")
            return sent_obj
          else
            raise "Error: more than one root node (stack length #{stack.length}). Full sentence: \n#{sentence}"
          end

        when /^\s*\(([^ )]+) /
          # match the beginning of a new constituent
          # (opening bracket + category + space, may not contain closing bracket)
          cat = $1
          if cat.nil? or cat == ""
            raise "Error: found category nil in sentence #{sentence[pos,10]}, full sentence\n#{sentence}"
          end
          #          STDERR.puts "new const #{cat}"
          stack.push cat # throw the category label on the stack
          return build_salsatiger(sentence, pos + $&.length, stack, termc, nontc, sent_obj)

        when /^\s*(\S+)\) /
          # match the end of a terminal constituent (something before a closing bracket + space)
          word = $1

          comb_cat = stack.pop
          if comb_cat.to_s == ""
            raise "Empty cat at position #{sentence[pos,10]}, full sentence\n#{sentence}"
          end

          cat, gf = split_cat(comb_cat)
          node = sent_obj.add_syn("t",
                                  nil,  # cat (doesn't matter here)
                                  STXML::SalsaTigerXMLHelper.escape(word), # word
                                  cat,  # pos
                                  termc.next.to_s)
          node.set_attribute("gf", gf)
          #          STDERR.puts "completed terminal #{cat}, #{word}"
          stack.push node
          return build_salsatiger(sentence, pos + $&.length, stack, termc, nontc, sent_obj)

        when /^\s*\)/ # match the end of a nonterminal (nothing before a closing bracket)
          # now collect children:
          # pop items from the stack until you find the category
          children = []
          while true
            if stack.empty?
              raise "Error: stack empty; cannot find more children"
            end

            item = stack.pop
            # @todo Change the check from string to class instances. 'SynNode' -> SynNode
            case item
            when STXML::SynNode # this is a child
              children.push item
            when String # this is the category label
              if item.to_s == ""
                raise "Empty cat at position #{sentence[pos,10]}, full sentence\n#{sentence}"
              end
              cat, gf = split_cat(item)
              break
            else
              raise "Error: unknown item class #{item.class}."
            end
          end

          # now add a nonterminal node to the sentence object and
          # register the children nodes
          node = sent_obj.add_syn("nt",
                                  cat, # cat
                                  nil, # word (doesn't matter)
                                  nil, # pos (doesn't matter)
                                  nontc.next.to_s)

          children.each do |child|
            child_gf = child.get_attribute("gf")
            child.del_attribute("gf")
            node.add_child(child,child_gf)
            child.add_parent(node, child_gf)
          end

          node.set_attribute("gf", gf)
          #          STDERR.puts "Completed nonterm #{cat}, #{children.length} children."
          stack.push node

          return build_salsatiger(sentence, pos + $&.length, stack,termc, nontc, sent_obj)
        else
          raise "Error: cannot analyse sentence at pos #{pos}: #{sentence[pos..-1]}. Complete sentence: \n#{sentence}"
        end
      end

      ###
      # StanfordParser delivers node labels as "phrase type"-"grammatical function",
      # but the GF may not be present.
      # @param cat [String]
      # @return [Array]
      def split_cat(cat)

        md = cat.match(/^([^-]*)(-([^-]*))?$/)
        raise "Error: Could not identify category in #{cat}!" unless md[1]

        proper_cat = md[1]
        gf = md[3] ? md[3] : ''

        [proper_cat, gf]
      end
    end
  end
end
