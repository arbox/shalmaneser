require 'salsa_tiger_xml/salsa_tiger_sentence'
require 'salsa_tiger_xml/syn_node'
require 'tempfile'
require_relative 'counter'
require 'frappe/syn_interface_stxml'
require 'tabular_format/fn_tab_format_file'

# Interface class
class CollinsInterface < SynInterfaceSTXML
  CollinsInterface.announce_me

  ###
  def self.system
    "collins"
  end

  ###
  def self.service
    "parser"
  end

  ###
  # initialize to set values for all subsequent processing
  def initialize(program_path, # string: path to system
                 insuffix,      # string: suffix of tab files
                 outsuffix,     # string: suffix for parsed files
                 stsuffix,      # string: suffix for Sals/TIGER XML files
                 var_hash = {}) # optional arguments in a hash

    super(program_path, insuffix, outsuffix, stsuffix, var_hash)
    # I am not expecting any parameters, but I need
    # the program path to end in a /.
    unless @program_path =~ /\/$/
      @program_path = @program_path + "/"
    end

    # new: evaluate var hash
    @pos_suffix = var_hash["pos_suffix"]
    @lemma_suffix = var_hash["lemma_suffix"]
    @tab_dir = var_hash["tab_dir"]
  end


  ###
  # parse a bunch of TabFormat files (*.<insuffix>) with Collins model 3
  # required: POS tags must be present
  # produced: in outputdir, files *.<outsuffix>
  # I assume that the files in inputdir are smaller than
  # the maximum number of sentences
  # Collins can parse in one go (i.e. that they are split) and I don't have to care
  def process_dir(in_dir,        # string: name of input directory
                  out_dir)       # string: name of output directory
    print "parsing ", in_dir, " and writing to ", out_dir, "\n"

    unless @pos_suffix
      raise "Collins interface: need suffix for POS files"
    end

    collins_prog = "gunzip -c #{@program_path}models/model3/events.gz | nice #{@program_path}code/parser"
    collins_params = " #{@program_path}models/model3/grammar 10000 1 1 1 1"

    Dir[in_dir+ "*" + @insuffix].each { |inputfilename|

      STDERR.puts "*** Parsing #{inputfilename} with Collins"

      corpusfilename = File.basename(inputfilename, @insuffix)
      parsefilename = out_dir + corpusfilename + @outsuffix
      tempfile = Tempfile.new(corpusfilename)

      # we need to have part of speech tags (but no lemmas at this point)
      # included automatically by FNTabFormatFile initialize from *.pos
      tabfile = FNTabFormatFile.new(inputfilename,@pos_suffix)

      CollinsInterface.produce_collins_input(tabfile,tempfile)
      tempfile.close
      print collins_prog+" "+tempfile.path+" "+ collins_params+" > "+parsefilename
      Kernel.system(collins_prog+" "+tempfile.path+" "+
                    collins_params+" > "+parsefilename)
      tempfile.close(true)
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
  def each_sentence(parsefilename)

    # sanity checks
    unless @tab_dir
      raise "Need to set tab directory on initialization"
    end

    # get matching tab file for this parser output file
    parserfile = File.new(parsefilename)
    tabfilename = @tab_dir+File.basename(parsefilename, @outsuffix)+ @insuffix

    corpusfile = FNTabFormatFile.new(tabfilename, @pos_suffix, @lemma_suffix)

    corpusfile.each_sentence {|tab_sent| # iterate over corpus sentences

      my_sent_id = tab_sent.get_sent_id

      while true # find next matching line in parse file
        line = parserfile.gets
        # search for the next "relevant" file or end of the file
        if line.nil? or line=~/^\(TOP/
          break
        end
      end
      STDERR.puts line
      # while we search a parse, the parse file is over...
      if line.nil?
        raise "Error: premature end of parser file!"
      end

      line.chomp!

      # it now holds that line =~ ^(TOP

      case line
      when /^\(TOP~/ # successful parse

        st_sent = SalsaTigerSentence.empty_sentence(my_sent_id.to_s)

        build_salsatiger(line,st_sent)

        yield [st_sent, tab_sent, CollinsInterface.standard_mapping(st_sent, tab_sent)]

      else
        # failed parse: create a "failed" parse object
        # with one nonterminal node and all the terminals

        sent = CollinsInterface.failed_sentence(tab_sent,my_sent_id)
        yield [sent, tab_sent, CollinsInterface.standard_mapping(sent, tab_sent)]

      end
    }
    # after the end of the corpusfile, check if there are any parses left
    while true
      line = parserfile.gets
      if line.nil? # if there are none, everything is fine
        break
      elsif line =~ /^\(TOP/ # if there are, raise an exception
        raise "Error: premature end of corpus file!"
      end
    end
  end

  ###
  # write Salsa/TIGER XML output to file
  def to_stxml_file(infilename,  # string: name of parse file
                    outfilename) # string: name of output stxml file

    outfile = File.new(outfilename, "w")
    outfile.puts SalsaTigerXMLHelper.get_header
    each_sentence(infilename) { |st_sent, tabsent|
      outfile.puts st_sent.get
    }
    outfile.puts SalsaTigerXMLHelper.get_footer
    outfile.close
  end


  ########################
  private

  # Build a SalsaTigerSentence corresponding to the Collins parse in argument string.
  #
  # Special features: removes unary nodes and traces
  def build_salsatiger(string,st_sent)

    nt_c = Counter.new(500)
    t_c = Counter.new(0)

    position = 0
    stack = []

    while position < string.length
      if string[position,1] == "(" # push nonterminal
        nextspace = string.index(" ",position)
        nonterminal = string[position+1..nextspace-1]
        stack.push nonterminal
        position = nextspace+1
      elsif string[position,1] == ")" # reduce stack
        tempstack = []
        while true
          # get all Nodes from the stack and put them on a tempstack,
          # until you find a String, which is a not-yet existing nonterminal
          object = stack.pop
          if object.kind_of? SynNode
            tempstack.push(object) # terminal or subtree
          else #  string (nonterminal label)
            if tempstack.length == 1 # skip unary nodes: do nothing and write tempstack back to stack
              stack += tempstack
              break
              # puts "Unary node #{object}"
            end
            nt_a = object.split("~")
            unless nt_a.length == 4
              # something went wrong. maybe it's about character encoding
              if nt_a.length > 4
                # yes, assume it's about character encoding
                nt_a = [nt_a[0], nt_a[1..-3].join("~"), nt_a[-2], nt_a[-1]]
              else
                # whoa, _less_ pieces than expected: problem.
                $stderr.puts "Collins parse tree translation nonrecoverable error:"
                $stderr.puts "Unexpectedly too few components in nonterminal " + nt_a.join("~")
                raise StandardError.new("nonrecoverable error")
              end
            end

            # construct a new nonterminal
            node = st_sent.add_syn("nt",
                                   SalsaTigerXMLHelper.escape(nt_a[0].strip), # cat
                                   nil, # word (doesn't matter)
                                   nil, # pos (doesn't matter)
                                   nt_c.next.to_s)
            node.set_attribute("head",SalsaTigerXMLHelper.escape(nt_a[1].strip))
            tempstack.reverse.each {|child|
              node.add_child(child,nil)
              child.set_parent(node,nil)
            }
            stack.push(node)
            break # while
          end
        end
        position = position+2 # == nextspace+1
      else # terminal
        nextspace = string.index(" ",position)
        terminal = string[position..nextspace].strip
        t_a = terminal.split("/")
        unless t_a.length == 2
          raise "[collins] Cannot split terminal #{terminal} into word and POS!"
        end

        word = t_a[0]
        pos = t_a[1]

        unless pos =~ /TRACE/
          # construct a new terminal
          node = st_sent.add_syn("t",
                                 nil,
                                 SalsaTigerXMLHelper.escape(CollinsInterface.unescape(word)), # word
                                 SalsaTigerXMLHelper.escape(pos), # pos
                                 t_c.next.to_s)
          stack.push(node)
        end
        position = nextspace+1
      end
    end

    # at the very end, we need to have exactly one syntactic root

    if stack.length != 1
      raise "[collins] Error: Sentence has #{stack.length} roots"
    end
  end


  ####
  # extract the Collins parser input format from a TabFormat object
  # that includes part-of-speech (pos)
  #
  def CollinsInterface.produce_collins_input(corpusfile,tempfile)
    corpusfile.each_sentence {|s|
      words = []
      s.each_line_parsed {|line_obj|
        word = line_obj.get("word")
        tag = line_obj.get("pos")
        if tag.nil?
          raise "Error: FNTabFormat object not tagged!"
        end
        word_tag_pair = CollinsInterface.escape(word,tag)
        if word_tag_pair =~ /\)/
          puts word_tag_pair
          puts s.to_s
        end
        words << word_tag_pair
      }
      tempfile.puts words.length.to_s+" "+words.join(" ")
    }
  end

  ####
  def CollinsInterface.escape(word,pos) # returns array word+" "+lemma
    case word

    # replace opening or closing brackets
    # word representation is {L,R}R{B,S,C} (bracket, square, curly)
    # POS for opening brackets is LRB, closing brackets RRB

    when "("
      return "LRB -LRB-"
    when "["
      return "LRS -LRB-"
    when "{"
      return "LRC -LRB-"

    when ")"
      return "RRB -RRB-"
    when "]"
      return "RRS -RRB-"
    when "}"
      return "RRC -RRB-"

    # catch those brackets or slashes inside words
    else
      word.gsub!(/\(/,"LRB")
      word.gsub!(/\)/,"RRB")
      word.gsub!(/\[/,"LRS")
      word.gsub!(/\]/,"RRS")
      word.gsub!(/\{/,"LRC")
      word.gsub!(/\}/,"RRC")
      word.gsub!(/\//,"&Slash;")

      word + " " + pos
    end
  end

  ####
  # replace replacements with original values
  def CollinsInterface.unescape(word)
    word.gsub(/LRB/,"(").gsub(/RRB/,")").gsub(/LRS/,"[").gsub(/RRS/,"]").gsub(/LRC/,"{").gsub(/RRC/,"}").gsub(/&Slash;/,"/")
  end
end
