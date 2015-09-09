#-*- coding: utf-8 -*-
####
# sp 21 07 05
#
# modified ke 30 10 05: adapted to fit into SynInterface
#
# represents a file containing Berkeley parses
#
# underlying data structure for individual sentences: SalsaTigerSentence
require "tempfile"

# require "common/SalsaTigerRegXML"
require 'common/salsa_tiger_xml/salsa_tiger_sentence'
require "common/SalsaTigerXMLHelper"
require "common/TabFormat"
require "common/Counter"

require "common/AbstractSynInterface"
require "common/tiger"

################################################
# Interface class
class BerkeleyInterface < SynInterfaceSTXML
  STDERR.puts 'Announcing Berkeley Interface' if $DEBUG
  BerkeleyInterface.announce_me

  def self.system
    'berkeley'
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
    super(program_path, insuffix, outsuffix, stsuffix, var_hash)

    # @togo AB: This should be checked in the OptionParser.
    unless @program_path =~ /\/$/
      @program_path += '/'
    end

    # new: evaluate var hash
    @pos_suffix = var_hash["pos_suffix"]
    @lemma_suffix = var_hash["lemma_suffix"]
    @tab_dir = var_hash["tab_dir"]
  end

  ####
  # parse a directory with TabFormat files and write the parse trees to outputdir
  # I assume that the files in inputdir are smaller than
  # the maximum number of sentences that
  # Berkeley can parse in one go (i.e. that they are split)
  def process_dir(in_dir,  # string: input directory name
		  out_dir) # string: output directory name


    parser = ENV['SHALM_BERKELEY_BIN'] || 'berkeleyParser.jar'
    grammar = ENV['SHALM_BERKELEY_MODEL'] || 'grammar.gr'
    options = ENV['SHALM_BERKELEY_OPTIONS']

    berkeley_prog = "java -jar #{@program_path}#{parser} #{options} -gr #{@program_path}#{grammar}"

    Dir[in_dir + "*" + @insuffix].each do |inputfilename|

      STDERR.puts "*** Parsing #{inputfilename} with Berkeley"
      corpusfilename = File.basename(inputfilename, @insuffix)
      parsefilename = out_dir + corpusfilename + @outsuffix
      tempfile = Tempfile.new(corpusfilename)

      # we need neither lemmata nor POS tags; berkeley can do with the words
      corpusfile = FNTabFormatFile.new(inputfilename, nil, nil)

      corpusfile.each_sentence do |sentence|
        #puts sentence
        tempfile.puts sentence
      end

      tempfile.close
      # parse and remove comments in the parser output
      STDERR.puts "#{berkeley_prog} < #{tempfile.path} > #{parsefilename}"

      # AB: for testing we leave this step out, it takes too much time.
      # Please keep the <parsefile> intact!!!
      rv = system("#{berkeley_prog} < #{tempfile.path} > #{parsefilename}")

      # AB: Testing for return value.
      unless rv
        fail 'Berkeley Parser failed to parse our files!'
      end
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
    # sanity checks
    unless @tab_dir
      raise "Need to set tab directory on initialization"
    end

    # get matching tab file for this parser output file
    parsefile = File.new(parsefilename)
    tabfilename = @tab_dir+File.basename(parsefilename, @outsuffix)+ @insuffix
    tabfile = FNTabFormatFile.new(tabfilename, @postag_suffix, @lemma_suffix)

    sentid = 0
    tabfile.each_sentence do |tab_sent| # iterate over corpus sentences

      sentence_str = ""
      status = true # error encountered?
      # assemble next sentence in Berkeley file by reading lines from parsefile
      # for berkeley:
      while true
        line = parsefile.gets

        # search for the next "relevant" file or end of the file
        # We expect here:
        # - an empty line;
        # - a failed parse;
        # - a parse beginning with <( (>, <( (TOP>, <( (VROOT> etc.
        # TOP - Negra Grammars
        # VROOT - Tiger Grammars
        # PSEUDO - Original BP Grammars
        # ROOT - some english grammars
        # empty identifiers for older Tiger grammars
	if line.nil? or line=~/^(\( *)?\((PSEUDO|TOP|ROOT|VROOT)? / or line=~/^\(\(\)/
          break
	end
        sentid +=1

      end


      if line.nil? # while we search a parse, the parse file is over...
        raise "Error: premature end of parser file!"
      end

      # Insert a top node <VROOT> if missing.
      # Some grammars trained on older Tiger Versions
      # expose this problem.
      #STDERR.puts "@@@1 <#{line}>"
      line.sub!(/^(\(\s+\()(\s+)/, '\1VROOT\2')
      #STDERR.puts "@@@2 <#{line}>"
      # berkeley parser output: remove brackets /(.*)/
      # Remove leading and trailing top level brackets.
      line.sub!(/^\( */, '')
      line.sub!(/ *\) *$/, '')

      # Split consequtive closing brackets.
      line.gsub!(/\)\)/, ') )')
      line.gsub!(/\)\)/, ') )')

      # Change CAT_FUNC delimiter from <_> to <->.
      line.gsub!(/(\([A-Z]+)_/, '\1-')

      sentence_str = line.chomp!

      # if we are here, we have a sentence_str to work on
      # hopefully, our status is OK
      case status
      when true
        if tab_sent.get_sent_id() and tab_sent.get_sent_id() != "--"
          my_sent_id = tab_sent.get_sent_id()
        else
          my_sent_id = File.basename(parsefilename, @outsuffix) + "_" + sentid.to_s
        end

        st_sent = build_salsatiger(" " + sentence_str + " ", 0,
                                   Array.new, Counter.new(0),
                                   Counter.new(500),
                                   SalsaTigerSentence.empty_sentence(my_sent_id.to_s))
	if st_sent.nil?
	  next
	end
        yield [st_sent, tab_sent, BerkeleyInterface.standard_mapping(st_sent, tab_sent)]
      else # i.e. when "failed"
        #raise "Hunh? This is a failed parse, but still we have a parse tree? Look again."
      end

    end

    # we don't have a sentence: hopefully, this is becase parsing has failed


    # all TabFile sentences are consumed:
    # now we may just encounter comments, garbage, empty lines etc.

    while not parsefile.eof?

      case abline = parsefile.gets
      when nil, /^%/, /^\s*$/ # empty lines, comments, end of input indicate end of current parse
      else
        raise "Error: premature end of tab file! Found line: #{abline}"
      end
    end
  end


  ###
  # write Salsa/TIGER XML output to file
  def to_stxml_file(infilename,  # string: name of parse file
		    outfilename) # string: name of output stxml file

    File.open(outfilename, 'w') do |outfile|
      outfile.puts SalsaTigerXMLHelper.get_header
      each_sentence(infilename) do |st_sent, tabsent|
        outfile.puts st_sent.get
      end
      outfile.puts SalsaTigerXMLHelper.get_footer
    end

  end



  ########################
  private

  ###
  # Recursive function for parsing a Berkeley parse tree and
  # building a SalsaTigerSentence recursively
  #
  # Algorithm: manage stack which contains, for the current constituent,
  # child constituents (if a nonterminal), and the category label.
  # When the end of a constituent is reached, a new SynNode (TigerSalsa node) ist created.
  # All children and the category label are popped from the stack and integrated into the
  # TigerSalsa data structure. The new node is re-pushed onto the stack.
  def build_salsatiger(sentence, # string
                    pos,      # position in string (index): integer
                    stack,    # stack with incomplete nodes: Array
                    termc,    # terminal counter
                    nontc,    # nonterminal counter
                    sent_obj) # SalsaTigerSentence



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
      return build_salsatiger(sentence,pos+$&.length,stack,termc,nontc,sent_obj)

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
                              SalsaTigerXMLHelper.escape(word), # word
                              cat,  # pos
                              termc.next.to_s)
      node.set_attribute("gf", gf)
#          STDERR.puts "completed terminal #{cat}, #{word}"
      stack.push node
      return build_salsatiger(sentence,pos+$&.length,stack,termc,nontc,sent_obj)

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
        case item.class.to_s
        when "SynNode" # this is a child
          children.push item
        when "String" # this is the category label
          if item.to_s == ""
            raise "Empty cat at position #{sentence[pos,10]}, full sentence\n#{sentence}"
          end
          cat, gf = split_cat(item)
          break
        else
          raise "Error: unknown item class #{item.class.to_s}"
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

      node.set_attribute("gf",gf)
#          STDERR.puts "Completed nonterm #{cat}, #{children.length} children."
      stack.push node

      return build_salsatiger(sentence,pos+$&.length, stack,termc,nontc,sent_obj)
    else
      raise "Error: cannot analyse sentence at pos #{pos}: <#{sentence[pos..-1]}>. Complete sentence: \n#{sentence}"
    end
  end

  ###
  # BerkeleyParser delivers node labels in different forms:
  # - "phrase type"-"grammatical function",
  # - "phrase type"_"grammatical function",
  # - "prase type":"grammatical function",
  # but the GF may be absent.
  # @param cat [String]
  # @return [Array<String>]
  def split_cat(cat)

    md = cat.match(/^([^-:_]*)([-:_]([^-:_]*))?$/)
    raise "Error: Could not identify category in #{cat}!" unless md[1]

    proper_cat = md[1]
    md[3] ? gf = md[3] : gf = ''

    [proper_cat, gf]
  end

end
