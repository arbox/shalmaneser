####
# sp 21 07 05
#
# modified ke 30 10 05: adapted to fit into SynInterface
#
# represents a file containing Sleepy parses
#
# underlying data structure for individual sentences: SalsaTigerSentence
require 'tempfile'

# require 'common/SalsaTigerRegXML'
require 'common/salsa_tiger_xml/salsa_tiger_sentence'
require 'common/SalsaTigerXMLHelper'
require 'common/TabFormat'
require 'common/Counter'

require 'common/AbstractSynInterface'
require 'common/tiger'

################################################
# Interface class
class SleepyInterface < SynInterfaceSTXML
  SleepyInterface.announce_me()

  ###
  def SleepyInterface.system()
    return "sleepy"
  end

  ###
  def SleepyInterface.service()
    return "parser"
  end

  ###
  # initialize to set values for all subsequent processing
  def initialize(program_path, # string: path to system
		 insuffix,      # string: suffix of tab files
		 outsuffix,     # string: suffix for parsed files
		 stsuffix,      # string: suffix for Salsa/TIGER XML files
		 var_hash = {}) # optional arguments in a hash

    super(program_path, insuffix, outsuffix, stsuffix, var_hash)
    unless @program_path =~ /\/$/
      @program_path = @program_path + "/"
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
  # Sleepy can parse in one go (i.e. that they are split)
  def process_dir(in_dir,  # string: input directory name
		  out_dir) # string: output directory name

    sleepy_prog = "#{@program_path}sleepy  --beam 1000 --model-file #{@program_path}negra.model --parse "

    Dir[in_dir + "*" + @insuffix].each {|inputfilename|
      STDERR.puts "*** Parsing #{inputfilename} with Sleepy"
      corpusfilename = File.basename(inputfilename, @insuffix)
      parsefilename = out_dir + corpusfilename + @outsuffix
      tempfile = Tempfile.new(corpusfilename)

      # we need neither lemmata nor POS tags; sleepy can do with the words
      corpusfile = FNTabFormatFile.new(inputfilename,nil, nil)
      corpusfile.each_sentence {|sentence|
        tempfile.puts sentence.to_s
      }
      tempfile.close
      # parse and remove comments in the parser output
      Kernel.system(sleepy_prog+" "+tempfile.path+" 2>&1 | grep -v \"Span:\" > "+parsefilename)
    }
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
      $stderr.puts "SleepyInterface error: Need to set tab directory on initialization"
      exit 1
    end

    # get matching tab file for this parser output file
    parsefile = File.new(parsefilename)
    tabfilename = @tab_dir+File.basename(parsefilename, @outsuffix)+ @insuffix
    tabfile = FNTabFormatFile.new(tabfilename, @postag_suffix, @lemma_suffix)

    sentid = 0

    tabfile.each_sentence {|tab_sent| # iterate over corpus sentences

      sentence_str = ""
      status = true # error encountered?

      # assemble next sentence in Sleepy file by reading lines from parsefile
      while true
        line = parsefile.gets
        case line
        when /% Parse failed/
          status = false
          break
        when nil # end of file: nothing more to break
          break
        when /^%/, /^\s*$/ # empty lines, other comments: end of current sentence
          unless sentence_str == "" # only break if you have read something
            break
          end
        else
          sentence_str += line.chomp # collect line of current parse and continue reading
        end
      end

      # we have reached some kind of end
      sentid +=1

      # we don't have a sentence: hopefully, this is becase parsing has failed
      # if this is not the case, we are in trouble
      if sentence_str == ""
        case status

        when false
          # return a SalsaTigerSentence object for the failed sentence
          # with a virtual top node and one terminal per word.
          if tab_sent.get_sent_id() and tab_sent.get_sent_id() != "--"
            my_sent_id = tab_sent.get_sent_id()
          else
            my_sent_id = File.basename(parsefilename, @outsuffix) + "_" + sentid.to_s
          end
          sent = SleepyInterface.failed_sentence(tab_sent, my_sent_id)
          yield [sent, tab_sent, SleepyInterface.standard_mapping(sent, tab_sent)]

        else
	  # this may not happen: we need some sentence for the current
	  # TabFile sentence
          $stderr.puts "SleepyInterface error: premature end of parser file!"
          exit 1
        end
      else
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
          yield [st_sent, tab_sent, SleepyInterface.standard_mapping(st_sent, tab_sent)]

        else # i.e. when "failed"
          $stderr.puts "SleepyInterface error: failed parse, but parse tree exists??"
          exit 1
        end
      end
    }

    # all TabFile sentences are consumed:
    # now we may just encounter comments, garbage, empty lines etc.

    while not parsefile.eof?
      case parsefile.gets
      when nil, /^%/, /^\s*$/ # empty lines, comments, end of input indicate end of current parse
      else
        $stderr.puts "SleepyInterface error: premature end of tab file"
        exit 1
      end
    end
  end


  ###
  # write Salsa/TIGER XML output to file
  def to_stxml_file(infilename,  # string: name of parse file
		    outfilename) # string: name of output stxml file

    outfile = File.new(outfilename, "w")
    outfile.puts SalsaTigerXMLHelper.get_header()
    each_sentence(infilename) { |st_sent, tabsent|
      outfile.puts st_sent.get()
    }
    outfile.puts SalsaTigerXMLHelper.get_footer()
    outfile.close()
  end



  ########################
  private

  ###
  # Recursive function for parsing a Sleepy parse tree and
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
        $stderr.puts "SleepyINterface Error: more than one root node (stack length #{stack.length}). Full sentence: \n#{sentence}"
        exit 1
      end

    when /^\s*\(([^ )]+) /
      # match the beginning of a new constituent
      # (opening bracket + category + space, may not contain closing bracket)
      cat = $1
      if cat.nil? or cat == ""
        $stderr.puts "SleepyInterface Error: found category nil in sentence #{sentence[pos,10]}, full sentence\n#{sentence}"
        exit 1
      end
#          STDERR.puts "new const #{cat}"
      stack.push cat # throw the category label on the stack
      return build_salsatiger(sentence,pos+$&.length,stack,termc,nontc,sent_obj)

    when /^\s*(\S+)\) /
      # match the end of a terminal constituent (something before a closing bracket + space)
      word = $1
      comb_cat = stack.pop
      if comb_cat.to_s == ""
        $stderr.puts "SleepyInterface error: Empty cat at position #{sentence[pos,10]}, full sentence\n#{sentence}"
        exit 1
      end
      cat,gf = split_cat(comb_cat)
      node = sent_obj.add_syn("t",
                              nil,  # cat (doesn't matter here)
                              SalsaTigerXMLHelper.escape(word), # word
                              cat,  # pos
                              termc.next.to_s)
      node.set_attribute("gf",gf)
#          STDERR.puts "completed terminal #{cat}, #{word}"
      stack.push node
      return build_salsatiger(sentence,pos+$&.length,stack,termc,nontc,sent_obj)

    when /^\s*\)/ # match the end of a nonterminal (nothing before a closing bracket)
      # now collect children:
      # pop items from the stack until you find the category
      children = Array.new
      while true
        if stack.empty?
          $stderr.puts  "SleepyInterface Error: stack empty; cannot find more children"
          exit 1
        end
        item = stack.pop
        case item.class.to_s
        when "SynNode" # this is a child
          children.push item
        when "String" # this is the category label
          if item.to_s == ""
            $stderr.puts "SleepyInterface error: Empty cat at position #{sentence[pos,10]}, full sentence\n#{sentence}"
            exit 1
          end
          cat,gf = split_cat(item)
          break
        else
          $stderr.puts "SleepyInterface Error: unknown item class #{item.class.to_s}"
          exit 1
        end
      end
      # now add a nonterminal node to the sentence object and
      # register the children nodes
      node = sent_obj.add_syn("nt",
                              cat, # cat
                              nil, # word (doesn't matter)
                              nil, # pos (doesn't matter)
                              nontc.next.to_s)
      children.each {|child|
        child_gf = child.get_attribute("gf")
        child.del_attribute("gf")
        node.add_child(child,child_gf)
        child.add_parent(node, child_gf)
      }
      node.set_attribute("gf",gf)
#          STDERR.puts "Completed nonterm #{cat}, #{children.length} children."
      stack.push node
      return build_salsatiger(sentence,pos+$&.length, stack,termc,nontc,sent_obj)
    else

      if sentence =~ /Fatal error: exception Out_of_memory/
        $stderr.puts "SleepyInterface error: Sleepy parser ran out of memory."
        $stderr.puts "Try reducing the max. sentence length"
        $stderr.puts "in the experiment file."
        exit 1
      end


      $stderr.puts "SleepyInterface Error: cannot analyse sentence at pos #{pos}:\n #{sentence[pos..-1]}\n Complete sentence: \n#{sentence}"
      exit 1
    end
  end

  ###
  # Sleepy delivers node labels as "phrase type"-"grammatical function"
  # but the GF may not be present.

  def split_cat(cat)

    cat =~ /^([^-]*)(-([^-]*))?$/
    unless $1
      $stderr.puts "SleepyInterface Error: could not identify category in #{cat}"
      exit 1
    end

    proper_cat = $1

    if $3
      gf = $3
    else
      gf = ""
    end

    return [proper_cat,gf]

  end
end



################################################
# Interpreter class
class SleepyInterpreter < Tiger
  SleepyInterpreter.announce_me()

  ###
  # names of the systems interpreted by this class:
  # returns a hash service(string) -> system name (string),
  # e.g.
  # { "parser" => "collins", "lemmatizer" => "treetagger" }
  def SleepyInterpreter.systems()
    return {
	"parser" => "sleepy"
    }
  end

  ###
  # names of additional systems that may be interpreted by this class
  # returns a hash service(string) -> system name(string)
  # same as names()
  def SleepyInterpreter.optional_systems()
    return {
      "lemmatizer" => "treetagger"
    }
  end

end
