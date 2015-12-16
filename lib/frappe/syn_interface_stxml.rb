require 'frappe/syn_interface'
require 'salsa_tiger_xml/file_parts_parser'

#############################
# abstract class, to be inherited:
#
# SalsaTigerXML interface for modules
# offering parsing etc.
#
# The input format for these classes is TabFormat or FNTabFormat
class SynInterfaceSTXML < SynInterface
  ###
  # initialize to set values for all subsequent processing
  def initialize(program_path, # string: path to system
                 insuffix,      # string: suffix of input files
                 outsuffix,     # string: suffix for processed files
                 stsuffix,      # string: suffix for Salsa/Tiger XML files
                 var_hash = {}) # optional arguments in a hash
    super(program_path, insuffix, outsuffix, var_hash)
    @stsuffix = stsuffix
  end

  def to_stxml_dir(in_dir,   # string: name of dir with parse files
                   out_dir)  # string: name of output dir

    Dir["#{in_dir}*#{@outsuffix}"].each do |parsefilename|
      stxmlfilename = "#{out_dir}#{File.basename(parsefilename, @outsuffix)}#{@stsuffix}"
      to_stxml_file(parsefilename, stxmlfilename)
    end
  end

  def to_stxml_file(infilename, outfilename)
    raise "Overwrite me"
  end

  ###
  # standard mapping:
  #
  # to be used as the mapping from tab sentence words to
  # SalsaTigerSentence nodes returned by each_sentence():
  # map the n-th word of the tab sentence to the n-th terminal of
  # the SalsaTigerSentence
  def self.standard_mapping(sent, tabsent)
    retv = {}

    if sent.nil?
        retv = nil
    else
      terminals = sent.terminals_sorted
      if tabsent
        tabsent.each_line_parsed do |l|
          if (t = terminals[l.get("lineno")])
            retv[l.get("lineno")] = [t]
          else
            retv[l.get("lineno")] = []
          end
        end
      end
    end

    retv
  end


  ###
  # for a given processed file:
  # yield each sentence as a tuple
  #  [SalsaTigerSentence object, FNTabFormatSentence object, mapping]
  # of
  # - the sentence in SalsaTigerXML,
  # - the matching tab format sentence
  # - a mapping of terminals:
  #   hash: line in tab sentence(integer) -> array:SynNode
  #   mapping tab sentence nodes to matching nodes in the SalsaTigerSentence data structure
  #
  # default version: write Salsa/Tiger XML to tempfile, read back in
  # and assume that each sentence in the tab file has a correspondent
  # in the processed file (may not hold e.g. if the parser leaves out
  # sentences it cannot process)
  def each_sentence(infilename,  # string: name of processed file
                    tab_dir = nil) # string: name of dir with input files
                                 # (set either here or on initialization)
    if tab_dir
      @tab_dir = tab_dir
    end

    # write Salsa/Tiger XML to tempfile
    tf = Tempfile.new("SynInterface")
    tf.close
    to_stxml_file(infilename, tf.path)
    tf.flush

    # get matching tab file, read
    tab_reader = get_tab_reader(infilename)
    tab_sentences = []
    tab_reader.each_sentence { |s| tab_sentences << s }

    # read Salsa/Tiger sentences and yield them
    reader = FilePartsParser.new(tf.path)
    sent_index = 0
    reader.scan_s { |sent_string|
      yield [
        SalsaTigerSentence.new(sent_string, tab_sentences[sent_index]),
        tab_sentences[sent_index],
        SynInterfaceSTXML.standard_mapping(sent, tab_sentences[sent_index])
      ]
      sent_index += 1
    }

    # remove tempfile
    tf.close(true)
  end

  #####################
  protected


  ###
  # get tab format file for a given processed file
  def get_tab_reader(infilename) # string: name of processed file
    # find matching non-processed file for processed file
    # assumption: directory with non-processed files
    # has been set as @tab_dir

    # sanity checks
    unless @tab_dir
      raise "Need to set tab directory"
    end

    # get matching tab file for this parser output file
    tabfilename = @tab_dir+File.basename(infilename, @outsuffix)+ @insuffix
    return FNTabFormatFile.new(tabfilename)
  end


  ###
  # provide a XML representation for a sentence that couldn't be analyzed
  # assuming a flat structure of all terminals, adding a virtual top node
  def SynInterfaceSTXML.failed_sentence(tab_sent,sentid)

    sent_obj = SalsaTigerSentence.empty_sentence(sentid.to_s)

    sent_obj.set_attribute("failed","true")

    topnode = sent_obj.add_syn("nt",
                               "NONE", # cat
                               nil, # word (doesn't matter)
                               nil, # pos (doesn't matter)
                               "500") # nonterminal counter

    t_counter = 0

    tab_sent.each_line_parsed {|line|
      t_counter += 1
      word = line.get("word")
      pos = line.get("pos")
      node = sent_obj.add_syn("t",
                              nil,  # cat (doesn't matter here)
                              SalsaTigerXMLHelper.escape(word), # word
                              pos,  # pos
                              t_counter.to_s)
      topnode.add_child(node,nil)
      node.add_parent(topnode, nil)
    }
    return sent_obj
  end
end
