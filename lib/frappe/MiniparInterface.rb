####
# KE Nov 2005
#
# Interface for use of the Minipar parser:
# parsing with Salsa/Tiger XML output format,
# class for interpreting the Salsa/Tiger XML data structures

require 'tempfile'
require 'common/TabFormat'
# require 'common/SalsaTigerRegXML'
require 'common/salsa_tiger_xml/salsa_tiger_sentence'
require 'common/SalsaTigerXMLHelper'

require 'common/AbstractSynInterface'

#########################################
# MiniparSentence class
#
# analyze one minipar output sentence,
# provide access
#
# hash representation of a node:
# keys are
#   index, word , lemma, pos, parent_index, edgelabel, governing_lemma, antecedent_index
#
# other access: as SalsaTigerSentence object
class MiniparSentence

  ########
  def initialize(sentence) # array:string, one minipar node per string
    @nodes = Array.new

    sentence.each { |line_string|
      @nodes << analyze_line(line_string)
    }
    # sort nodes by line index -- sometimes nodes with lower index are mentioned later in the sentence
    @nodes.sort! { |a, b| a["index"].to_i <=> b["index"].to_i }

    @tabsent = nil
    # nodehash_mapping: hash tabindex -> array:nodehashes
    @nodehash_mapping = nil
  end

  #####
  def nodes()
    return @nodes.clone.freeze()
  end

  #####3
  # stxml:
  #
  # make SalsaTigerSentence object from this sentence,
  # one node per minipar node.
  # if it is a nonterminal, duplicate it as a terminal
  #
  # return: pair [SalsaTigerSentence, mapping]:
  # if we have a tab sent, mapping is a mapping from tab word indices to SynNode objects
  # of the minipar sentence representation
  def stxml(sentence_id)
    return salsatigerxml_output(sentence_id)
  end

  #####
  # set tabsent:
  # set this tab format sentence, which has entries "word", "lineno",
  # as the sentence matching this minipar output sentence.
  #
  # On success, remember the tab sentence as well as the mapping
  # between fntab sentence indices and minipar node hash indices
  #
  # returns true on success
  #         or false if matching failed

  def set_tabsent(tabsent, # TabFileFormat object
                  sloppy = true) # not nil or false: allow sloppy match

    # empty minipar sentence? then no match
    if @nodes.empty?
      return false
    end

    # tabwords: array:string
    tabwords = Array.new
    tabsent.each_line_parsed { |l| tabwords << l.get("word") }

    # main data structure: a chart of partial mappings fn_index -> minipar_index
    # represented as an array of partial mappings
    # each partial mapping is an array of triples [fn_index, min_index, "full"|"partial"]
    old_chart = Array.new

    # enter data for 1st minipar node into the chart
    first_node_no = 0
    while @nodes[first_node_no]["word"].nil?
      first_node_no += 1
    end
    old_chart = fnw_minw_match(tabwords, @nodes[first_node_no]["word"]).map { |fnw_index, match_how|
      [[fnw_index, first_node_no, match_how]]
    }

    if old_chart.empty?
      # unmatched single word in minipar sentence
      return false
    end

    # enter data for the rest of the minipar nodes into the chart
    (first_node_no + 1).upto(@nodes.length - 1) { |node_no|
      unless @nodes[node_no]["word"]
        # minipar node with empty word, skip
        next
      end
      new_chart = []

      # each partial mapping found up to now:
      # try to extend it, record results in new_chart
      old_chart.each { |partial_mapping|
        prev_fnw_index, _prev_mw_index, match_how = partial_mapping.last

        # where do we start looking in tabwords? same word as before, or advance one?
        case match_how
        when "full"
          fnw_index = prev_fnw_index + 1
        when "partial"
          fnw_index = prev_fnw_index
        else
          raise "Shouldn't be here"
        end

        fnw_minw_match(tabwords[fnw_index..tabwords.length-1],
                       @nodes[node_no]["word"]).each { |match_offset, _match_how|
          new_chart.push partial_mapping + [[fnw_index + match_offset, node_no, match_how]]
        }
      }

      if new_chart.empty?
        # no partial mappings found that would work up to this minipar node:
        # matching failed
        return false
      end

      old_chart = new_chart
    }

    #     $stderr.puts "Msent: "+ @nodes.map { |n| n["word"]}.join(" ")
    #     $stderr.puts "Tsent: "+ tabwords.join(" ")
    #     $stderr.puts "Mappings: "
    #     old_chart.each { |mapping|
    #       mapping.each { |fnw_ix, mnode_no, match_how|
    #         $stderr.print tabwords[fnw_ix] + ":" + @nodes[mnode_no]["word"] + ":" + match_how + " "
    #       }
    #       $stderr.puts
    #     }
    #     $stderr.puts "any key"
    #     $stdin.gets()

    # filter chart: if some fntab sent words are only matched partially, discard
    if sloppy
      chart = old_chart
    else
      chart = old_chart.select { |mapping|

        mapping_ok = true
        tabwords.each_with_index { |fnw, fnw_index|

          tuples = mapping.select { |other_fnw_index, mnode_no, match_how| other_fnw_index == fnw_index }

          unless tuples.empty?
            word = tuples.map { |_fnw_index, mnode_no, match_how| @nodes[mnode_no]["word"] }.join

            unless word == fnw
              mapping_ok = false
              break
            end
          end
        }
        mapping_ok
      }
    end

    if chart.empty?
      return false
    elsif chart.length() > 1
      #      $stderr.puts "Found more than one mapping for sentence:"
      #      $stderr.puts "Msent: " + @nodes.map { |n| n["word"]}.join(" ")
      #      $stderr.puts "Tsent: "+ tabwords.join(" ")
      #      $stderr.puts
    end

    # success: found mapping
    # nodehash_mapping: hash tab sentence word index -> array: SynNodes
    @tabsent = tabsent
    @nodehash_mapping = Hash.new
    chart.first.each { |tabindex, mindex, match_how|
      unless @nodehash_mapping[tabindex]
        @nodehash_mapping[tabindex] = Array.new
      end
      @nodehash_mapping[tabindex] << @nodes[mindex]
    }
    return true
  end

  # nodehash_mapping: hash tabindex -> array:nodehashes
  def nodehash_mapping()
    if @nodehash_mapping
      return @nodehash_mapping.clone.freeze()
    else
      return nil
    end
  end


  ################################################3
  ################################################3
  private

  ###########
  # analyze one line of the sentence array.
  #
  # examples of possible entries:
  # E1      (()     fin C   E4      )
  # 3       (them   ~ N     2       obj     (gov call))
  # E5      (()     they N  2       subj    (gov call)      (antecedent 1))
  def analyze_line(line)
    retv = Hash.new()

    unless line =~ /^(\w+)\t\((.+)\)\s*$/
      raise "Cannot parse line: #{line}"
    end

    # line structure:
    # index ( node descr )
    retv["index"] = $1

    descr = $2
    word, lemma_pos, parentindex, edgelabel, governor, antecedent = descr.split("\t")

    # word
    if word
      if word =~ /^['"](.+)['"]$/
        # quoted? remove quotes
        word = $1
      end
      unless word == "()"
        retv["word"] = word
      end
    end

    # lemma, POS
    if lemma_pos
      lemma_pos.strip!
      if lemma_pos == "U"
      # neither lemma nor POS for this node
      else
        # we have both lemma and POS

        if lemma_pos =~ /^(.+)\s(.+)$/
          # lemma may be "...." with spaces in.
          # this regexp. uses the last space to separate lemma and POS
          retv["lemma"] = $1
          retv["pos"] = $2

          if retv["lemma"] =~ /^"(.+)"$/
            # remove quotes around lemma
            retv["lemma"] = $1

          elsif retv["lemma"] == "~"
            # lemma same as word
            retv["lemma"] = retv["word"]
          end
        elsif lemma_pos.strip().split().length() == 1
          # only pos given
          retv["pos"] = lemma_pos.strip()
        else
          $stderr.puts "cannot parse lemma_pos pair " + lemma_pos
        end
      end
    end

    # parent index
    if parentindex.nil? or parentindex == "*"
    # root
    else
      retv["parent_index"] = parentindex
    end

    # edge label
    if edgelabel.nil? or edgelabel.strip.empty?
    # no edge label given
    else
      retv["edgelabel"] = edgelabel
    end

    # governing word
    if governor and not(governor.strip.empty?)
      # expected format:
      # (gov <governing_lemma>)
      if governor =~ /^\(gov\s(.+)\)$/
        retv["governing_lemma"] = $1
      elsif governor == "(gov )"
      # okay, no governor given
      else
        $stderr.puts "cannot parse governor "+ governor
      end
    end

    # antecedent
    if antecedent and not(antecedent.strip.empty?)
      # expected format:
      # (antecedent <index>)
      if antecedent =~ /^\(antecedent\s(.+)\)$/
        retv["antecedent_index"] = $1
      else
        $stderr.puts "cannot parse antecedent "+ antecedent
      end
    end

    return retv
  end

  ###########
  # returns: SalsaTigerSentence object describing this minipar parse
  def salsatigerxml_output(sentence_id)

    # start sentence object
    sent_obj = SalsaTigerSentence.empty_sentence(sentence_id)

    # determine children of each node
    # so we'll know which nodes to make terminal and which to make nonterminal
    i_have_children = Hash.new
    @nodes.each { | node|
      if (parent_ix = node["parent_index"])
        # node has parent. record the parent as having children
        i_have_children[parent_ix] = true
      end
    }

    # make SynNode objects for each minipar node
    # minipar terminal: one SynNode terminal
    # minipar nonterminal: one SynNode nonterminal, plus one SynNode terminal
    #                      duplicating the word, lemma and POS info
    #                      to keep with the SalsaTigerSentence assumptions that
    #                      the sentence can be read off from the terminals
    index_to_synnode = Hash.new
    @nodes.each { |minipar_node|
      node_id = minipar_node["index"]
      if minipar_node["word"]
        word = SalsaTigerXMLHelper.escape(minipar_node["word"])
      elsif not(i_have_children[minipar_node["index"]])
        # node without word and children: probably has an antecedent
        # add an empty word so the Salsa tool can represent the node with the antecedent
        word = ""
      else
        word = nil
      end

      if word
        # make a terminal SynNode for this minipar node
        # only if it has a word, otherwise it's not much use as a terminal
        t_node = sent_obj.add_syn("t",
                                  nil,  # category
                                  word, # word
                                  minipar_node["pos"], # POS
                                  node_id) # node ID
        if minipar_node["lemma"]
          t_node.set_attribute("lemma", SalsaTigerXMLHelper.escape(minipar_node["lemma"]))
        end

        # remember this node
        index_to_synnode[minipar_node["index"]] = t_node
      else
        t_node = nil
      end

      if i_have_children[minipar_node["index"]] or not(word)
        # does this minipar node have children, or
        # does it lack a word? then add a (second) nonterminal SynNode for it
        node_id = node_id + "nt"
        nt_node = sent_obj.add_syn("nt",
                                   minipar_node["pos"],  # category
                                   word, # word
                                   minipar_node["pos"], # POS
                                   node_id) # node ID
        if minipar_node["lemma"]
          nt_node.set_attribute("lemma", SalsaTigerXMLHelper.escape(minipar_node["lemma"]))
        end

        # link t node to nt node
        if t_node
          nt_node.add_child(t_node, "Head")
          t_node.add_parent(nt_node, "Head")
        end

        # just terminal node: remember it
        # both terminal and nonterminal:remember just the nonterminal
        index_to_synnode[minipar_node["index"]] = nt_node
      end

    }

    # link SynNodes
    @nodes.each { |minipar_node|
      # find my syn node
      my_synnode = index_to_synnode[minipar_node["index"]]
      unless my_synnode
        raise "Error: no syn node constructed for index in sentence #{sentence_id}"
      end

      # link to parent syn node
      if (parent_ix = minipar_node["parent_index"])
        parent_synnode = index_to_synnode[parent_ix]
        unless parent_synnode
          raise "Error: no syn node constructed for parent index #{parent_ix} in sentence #{sentence_id}"
        end

        parent_synnode.add_child(my_synnode, minipar_node["edgelabel"])
        my_synnode.add_parent(parent_synnode, minipar_node["edgelabel"])
      end

      # remember antecedent: both the node itself and its index, the latter as an attribute
      # this way, we have
      # - easy access to the antecedent via the node itself
      # - a record of the antecedent in the SalsaTigerXML output
      if (antecedent_ix = minipar_node["antecedent_index"])
        antecedent_synnode = index_to_synnode[antecedent_ix]
        unless antecedent_synnode
          raise "Error: no syn node constructed for antecedent index #{antecedent_ix} in sentence #{sentence_id}"
        end

        my_synnode.set_f("antecedent", antecedent_synnode)
        my_synnode.set_attribute("antecedent", antecedent_synnode.id())
      end
    }

    return [sent_obj, construct_tabsent_mapping_stxml(sent_obj)]
  end

  ###########3
  # construct mapping fntab line -> array of SynNodes
  # and add fntab words not present in minipar as children of the
  # SalsaTigerSentence object's root
  def construct_tabsent_mapping_stxml(sent)
    unless @tabsent
      return nil
    end

    retv = Hash.new
    prev_minipar_index = nil

    @tabsent.each_line_parsed { |tabline|
      retv[tabline.get("lineno")] = Array.new

      # nodehash_mapping: hash tabsent lineno -> array: member of @nodes
      if (nodehashes = @nodehash_mapping[tabline.get("lineno")])
        nodehashes.each { |nodehash|
          prev_minipar_index = nodehash["index"]

          # this tabsent word has a corresponding minipar node
          # enter it in tabsent_mapping
          if (node = sent.syn_node_with_id(sent.id() + "_" + nodehash["index"]))
            # terminal matching this fntab word
            retv[tabline.get("lineno")] << node
          elsif (node = sent.syn_node_with_id(sent.id() + "_" + nodehash["index"] + "nt"))
            # we have a nonterminal matching this fntab word
            retv[tabline.get("lineno")] << node
          else
            # no match after all?
            raise "missing: SalsaTigerSentence node for minipar node with index #{nodehash["index"]}"
          end
        }

      else
        # this tabsent word has no corresponding minipar node yet
        # make one. See to it that it occurs in the right spot in sent.terminals_ordered.
        parent = sent.syn_roots.first
        node = sent.add_syn("t", # terminal
                            "",  # category
                            tabline.get("word"), # word
                            "", # part of speech
                            (prev_minipar_index.to_i + 1).to_s) # ID
        parent.add_child(node, "-")
        node.add_parent(parent, "-")

        retv[tabline.get("lineno")] = [node]
      end
    }

    return retv
  end

  ######
  # return a list of pairs [fntab word index, match type]
  # with an entry for each fntab word on fnw_list that matches minw,
  # either fnw == minw (match_type "full") or minw part_of fnw (match_type "partial")
  def fnw_minw_match(fnw_list, minw)
    retv = Array.new

    fnw_list.each_with_index { |fnw, fnw_index|
      if fnw == minw
        # words identical
        retv << [fnw_index, "full"]
      elsif fnw.index(minw)
        # fn word includes minipar word
        retv << [fnw_index, "partial"]
      end
    }

    return retv
  end
end



################################################
# Interface class
class MiniparInterface < SynInterfaceSTXML
  MiniparInterface.announce_me()

  ###
  def MiniparInterface.system()
    return "minipar"
  end

  ###
  def MiniparInterface.service()
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

    # new: evaluate var hash
    @pos_suffix = var_hash["pos_suffix"]
    @lemma_suffix = var_hash["lemma_suffix"]
    @tab_dir = var_hash["tab_dir"]
  end


  ###
  # process one file, writing the result to outfilename
  #  input format is FNTabFormat, output format is
  #  Minipar format
  #
  # returns: nothing
  def process_file(infilename,    # string: name of input file
                   outfilename)    # string: name of output file

    tf = Tempfile.new("minipar")
    reader = FNTabFormatFile.new(infilename)
    reader.each_sentence { |sent|
      sent.each_line_parsed { |line|
        tf.print line.get("word"), " "
      }
      tf.puts
    }

    tf.close()
    %x{#{@program_path} < #{tf.path()} > #{outfilename}}
  end

  #########3
  # yields tuples
  #  [ minipar output sentence, tab sentence, mapping]
  #
  # minipar output sentence is
  #  - either an array of hashes, each describing one node;
  #  - or a SalsaTigerSentence object
  #  - or a MiniparSentence object
  #    (which has methods returns the sentence as either a
  #     nodehash array or a SalsaTigerSentence)
  #
  # tab sentence: matching tab sentence, if tab file has been given on initialization
  #
  # mapping: hash: line in tab sentence(integer) -> array:SynNode
  #   mapping tab sentence nodes to matching nodes in the SalsaTigerSentence data structure
  #
  # If a parse has failed, returns
  #  [failed_sentence (flat SalsaTigerSentence), FNTabFormatSentence]
  # to allow more detailed accounting for failed parses
  def each_sentence(parsefilename,    # name of minipar output file
                    format = "stxml") # format to return data in
    # sanity checks
    unless @tab_dir
      raise "Need to set tab directory on initialization"
    end

    # get matching tab file for this parser output file,
    # read its contents
    tabfilename = @tab_dir+File.basename(parsefilename, @outsuffix)+ @insuffix
    @tab_sentences = Array.new
    reader = FNTabFormatFile.new(tabfilename)
    reader.each_sentence { |sent_obj| @tab_sentences << sent_obj  }

    stream = open_minipar_outfile(parsefilename)

    sentno = 0
    tab_sentno = 0
    matched_tabsent = Hash.new()

    each_miniparsent_obj(stream) { |parse|

      if (matching_tab_sentno = matching_tabsent(parse, tab_sentno))
        # found matching tab sentence
        tabsent = @tab_sentences[matching_tab_sentno]
        tab_sentno = matching_tab_sentno + 1
        matched_tabsent[matching_tab_sentno] = true
      else
        tabsent = nil
      end

      # yield minipar parse in the required format
      case format
      when "nodehashes"
        yield [parse.nodes(), tabsent, parse.nodehash_mapping()]
      when "stxml"
        sent, mapping = parse.stxml(@filename_core + sentno.to_s)
        yield [sent, tabsent, mapping]
      when "objects"
        yield [parse, tabsent]
      else
        raise "Unknown each_sentence format #{format}"
      end

      sentno += 1
    }

    ##
    # each unmatched tab sentence: yield as failed parse object
    @tab_sentences.each_with_index { |tabsent, index|
      unless matched_tabsent[index]
        # spotted an unmatched sentence
        sent = MiniparInterface.failed_sentence(tabsent,tabsent.get_sent_id())
        yield [sent, tabsent, MiniparInterface.standard_mapping(sent, tabsent)]
      end
    }
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


  #####################3
  private

  ###
  # open minipar outfile
  #
  # return: IO stream for reading minipar outfile
  def open_minipar_outfile(filename)

    ##
    # zipped? then unzip first
    # (the Ruby read-zipped package doesn't seem to be reliable)
    if filename =~  /\.gz$/
      @filename_core = File.basename(filename, ".gz")
      return IO.popen("zcat #{filename}")
    else
      @filename_core = File.basename(filename)
      begin
        return File.new(filename)
      rescue
        raise "Couldn't read minipar file #{filename}"
      end
    end
  end

  ###
  # each_miniparsent_obj
  # read minipar output from stream,
  # yield sentence-wise as MiniparSentence objects
  def each_miniparsent_obj(stream) # IO object: stream to read from

    # status: string
    # "outside": waiting for next start of sentence with ( alone in a line
    # "inside": inside a sentence, sentence ends with ) alone on a line
    status = "outside"

    # sentence: array of strings, one for each line of the sentence
    sentence = Array.new()

    while (line = stream.gets())
      case status
      when "outside"
        # start of sentence?
        if ["(", "> ("].include? line.chomp().strip()
          sentence.clear()
          status = "inside"
        end

      when "inside"
        if line.chomp().strip() == ")"
          # end of sentence
          yield MiniparSentence.new(sentence)
          status = "outside"
        else
          # inside sentence
          sentence << line.chomp().strip()
        end
      else
        raise "Shouldn't be here"
      end # case
    end # while file not ended
  end

  ###
  # matching_tabsent
  #
  # if we have tab sentences, and if there is
  # a tab sentence matching the given minipar sentence,
  # return its index, else return false
  #
  # If there is a matching tabsent,
  # the MiniparSentence will remember it (and the terminal mapping)
  def matching_tabsent(parse,  # MiniparSentence object
                       tabsent_no) # integer: starting point in @tab_sentences array
    if @tab_sentences.empty?
      return nil
    end

    tabsent_no.upto(@tab_sentences.length() - 1) { |index|
      if parse.set_tabsent(@tab_sentences[index])
        return index
      end
    }

    # no match found up to now. so try sloppy match
    if parse.set_tabsent(@tab_sentences[tabsent_no], "sloppy")
      #      $stderr.puts "Warning: sloppy match used. Minipar sentence:"
      #      $stderr.puts parse.nodes().map { |n| n["word"].to_s }.join(" ")
      #      $stderr.puts "Matching fntab sentence: "
      #      @tab_sentences[tabsent_no].each_line_parsed { |l| $stderr.print l.get("word"), " " }
      #      $stderr.puts
      return tabsent_no
    end

    #    $stderr.puts "Warning: No match found for minipar sentence:"
    #    $stderr.puts parse.nodes().map { |n| n["word"].to_s }.join(" ")
    #    $stderr.puts "First tested fntab sentence: "
    #    @tab_sentences[tabsent_no].each_line_parsed { |l| $stderr.print l.get("word"), " " }
    #    $stderr.puts

    return nil
  end
end

################################################
# Interpreter class
class MiniparInterpreter < SynInterpreter
  MiniparInterpreter.announce_me()

  ###
  # names of the systems interpreted by this class:
  # returns a hash service(string) -> system name (string),
  # e.g.
  # { "parser" => "collins", "lemmatizer" => "treetagger" }
  def MiniparInterpreter.systems()
    return {
      "parser" => "minipar"
    }
  end

  ###
  # names of additional systems that may be interpreted by this class
  # returns a hash service(string) -> system name(string)
  # same as names()
  def MiniparInterpreter.optional_systems()
    return {}
  end

  ###
  # generalize over POS tags.
  #
  # returns one of:
  #
  # adj:  adjective (phrase)
  # adv:  adverb (phrase)
  # card: numbers, quantity phrases
  # con:  conjunction
  # det:  determiner, including possessive/demonstrative pronouns etc.
  # for:  foreign material
  # noun: noun (phrase), including personal pronouns, proper names, expletives
  # part: particles, truncated words (German compound parts)
  # prep: preposition (phrase)
  # pun:  punctuation, brackets, etc.
  # sent: sentence
  # top:  top node of a sentence
  # verb: verb (phrase)
  # nil:  something went wrong
  #
  # returns: string, or nil
  def MiniparInterpreter.category(node) # SynNode
    node = MiniparInterpreter.ensure_upper(node)

    if node.get_attribute("lemma") =~ /NUM/
      return "card"
    end

    if node.part_of_speech() == "U" and
      node.parent_label() == "lex-mod" and
      node.parent and MiniparInterpreter.category(node.parent) == "verb"
      # this node is part of a complex verb
      return "part"
    end

    if node.word =~ /^[!?;`'",(){}\[\]\.\:]+$/
      return "pun"
    end

    if node.parent.nil?
      return "top"
    end

    case node.part_of_speech()

    when "A"  # same POS for adjectives and adverbs
      parent = node.parent
      if parent
        if MiniparInterpreter.category(parent) == "verb"
          return "adv"
        else
          return "adj"
        end
      else
        return "adj"
      end

    when "Det"
      return "det"
    when "N"
      return "noun"

    when "Prep"
      return "prep"

    when "C"
      return "sent"

    when /^V/
      return "verb"

    else
      return nil
    end
  end

  ###
  # is relative pronoun?
  #
  def MiniparInterpreter.relative_pronoun?(node) # SynNode
    if node.parent_label() =~ /^wh/
      return true
    else
      return false
    end
  end

  ###
  # phrase type:
  # constituent label for nonterminals,
  # part of speech for terminals
  #
  # returns: string
  def MiniparInterpreter.pt(node)
    return node.part_of_speech()
  end

  ###
  # auxiliary?
  #
  # returns true if the given node is an auxiliary
  #
  # returns: boolean
  def MiniparInterpreter.auxiliary?(node)
    if MiniparInterpreter.aux_or_modal?(node) and
      not(MiniparInterpreter.modal?(node))
      return true
    else
      return false
    end
  end

  ###
  # modal?
  #
  # returns true if the given node is a modal verb
  #
  # returns: boolean
  def MiniparInterpreter.modal?(node)
    if MiniparInterpreter.aux_or_modal?(node) and
      ["can",
       "could",
       "must",
       "should",
       "shall"
      ].include? node.word()
      return true
    else
      return false
    end
  end

  ###
  # head_terminal
  #
  # given a constituent, return the terminal node
  # that describes its headword
  #
  # returns: a SynNode object if successful, else nil
  def MiniparInterpreter.head_terminal(node)
    if node.is_terminal?
      return node
    else
      return node.children_by_edgelabels(["Head"]).first
    end
  end

  ###
  # voice
  #
  # given a constituent, return
  # - "active"/"passive" if it is a verb
  # - nil, else
  def MiniparInterpreter.voice(verb_node)

    # am I a terminal added to make minipar representations
    # more TigerXML-like? then move to my parent
    verb_node = MiniparInterpreter.ensure_upper(verb_node)

    # verb has to have part of speech V or VBE
    unless ["V", "VBE"].include? verb_node.part_of_speech()
      return nil
    end

    # outgoing edge "by_subj"?
    # then assume passive
    unless verb_node.children_by_edgelabels(["by_subj"]).empty?
      #      $stderr.puts "passive #{verb_node.id()} by_subj"
      return "passive"
    end

    # outgoing edge to auxiliary "be", and not "be ....ing"?
    # then assume passive
    if not(verb_node.children_by_edgelabels(["be"]).empty?) and
      verb_node.word !~ /ing$/
      #      $stderr.puts "passive #{verb_node.id()} be"
      return "passive"
    end

    # vrel incoming edge? then assume passive
    if verb_node.parent_label() == "vrel"
      #      $stderr.puts "passive #{verb_node.id()} vrel"
      return "passive"
    end

    # obj child coreferent with s child?
    # then assume passive
    if (obj_ch = verb_node.children_by_edgelabels(["obj"]).first)
      if (s_ch = verb_node.children_by_edgelabels(["s"]).first)
        if obj_ch.get_f("antecedent") == s_ch
          #          $stderr.puts "passive #{verb_node.id()} obj=s"
          return "passive"
        end
      end
    end

    # okay, assume active voice
    return "active"
  end

  ###
  # gfs
  #
  # grammatical functions of a constituent:
  #
  # returns: a list of pairs [relation(string), node(SynNode)]
  # where <node> stands in the relation <relation> to the parameter
  # that the method was called with
  def MiniparInterpreter.gfs(start_node,    # SynNode
                             sent)    # SalsaTigerSentence

    start_node = MiniparInterpreter.ensure_upper(start_node)

    retv =  start_node.children_with_edgelabel.reject { |edgelabel, node|
      ["Head",  # head of the target node -- not really bearer of a GF
       "-",
       "aux",
       "have",
       "be"
      ].include? edgelabel
    }.map { |edgelabel,node|

      # map node to suitable other node
      while (ant_id = node.get_attribute("antecedent"))

        # Antecedent node for empty nodes and relative pronouns

        new_node = sent.syn_node_with_id(ant_id)
        if new_node
          node = new_node
        else
          # error. stop seeking
          #         $stderr.puts "Antecedent ID not matching any node: #{ant_id}"
          break
        end
      end

      # PP -- i.e. edgelabel == mod and node.POS == Prep?
      # then add the preposition to the edgelabel,
      # and take the node's head as head instead of the node
      if edgelabel == "mod" and
        node.part_of_speech() == "Prep"
        edgelabel = edgelabel + "-" + node.word().to_s
      end

      [edgelabel, node]
    }

    # duplicate entries?
    # s is often coreferent with either subj or obj
    if MiniparInterpreter.voice(start_node) == "active" and
      (s_entry = retv.assoc("s")) and
      (subj_entry = retv.assoc("subj")) and
      s_entry.last == subj_entry.last
      retv.delete(s_entry)

    elsif MiniparInterpreter.voice(start_node) == "passive" and
         (s_entry = retv.assoc("s")) and
         (obj_entry = retv.assoc("obj")) and
         s_entry.last == obj_entry.last
      retv.delete(s_entry)
    end

    #    $stderr.puts "blip " + retv.map { |l, n| l}.join(" ")
    return retv
  end

  ###
  # informative_content_node
  #
  # for most constituents: the head
  # for a PP, the NP
  # for an SBAR, the VP
  # for a VP, the embedded VP
  def MiniparInterpreter.informative_content_node(node)
    node = MiniparInterpreter.ensure_upper(node)

    if node.part_of_speech() == "Prep"
      # use complement of this constituent
      children = node.children_by_edgelabels(["pcomp-n",
                                              "vpsc_pcomp-c",
                                              "pcomp-c"])

      if children.empty?
        # no suitable child found
        #        $stderr.puts "Prep node without suitable child."
        #        $stderr.puts "Outgoing edges: " + node.child_labels().join(", ")
        return nil

      else
        #         if children.length() > 1
        #           $stderr.puts "Too many suitable children for prep node: "
        #           $stderr.puts "Outgoing edges: " + node.child_labels().join(", ")
        #         end

        return children.first
      end


    elsif node.part_of_speech() == "SentAdjunct"
      # use complement of this constituent
      children = node.children_by_edgelabels(["comp1"])

      if children.empty?
        # no suitable child found
        #        $stderr.puts "SentAdjunct node without suitable child."
        #        $stderr.puts "Outgoing edges: " + node.child_labels().join(", ")
        return nil

      else
        #         if children.length() > 1
        #           $stderr.puts "Too many suitable children for sent. adjunct node: "
        #           $stderr.puts "Outgoing edges: " + node.child_labels().join(", ")
        #         end

        return children.first
      end

    elsif node.word().nil? or node.word().empty?
      # no word for this node: use child instead

      children = node.children_by_edgelabels(["i"])
      if children.length() > 0
        #         if children.length() > 1
        #           $stderr.puts "Too many i edges from empty node."
        #         end

        return children.first
      end

      children = node.children_by_edgelabels(["nn"])
      if children.length() > 0
        #         if children.length() > 1
        #           $stderr.puts "Too many nn edges from empty node."
        #         end

        return children.first
      end

      # no children for this node: try antecedent
      ant = node.get_f("antecedent")
      if ant
        return ant
      end

      return nil
    end

  end

  ###
  # path_between
  #
  # construct path in syntactic structure between two nodes,
  # using
  # - node labels
  # - edge labels
  # - direction Up, Down
  #
  # use_nontree_edges: set to true to use coreference edges
  # and other non-tree edges returned by the parser
  # in path computation.
  #
  # returns: Path object
  def MiniparInterpreter.path_between(from_node, # SynNode
                                      to_node,   # SynNode
                                      use_nontree_edges = false) # boolean
    from_node = MiniparInterpreter.ensure_upper(from_node)
    to_node = MiniparInterpreter.ensure_upper(to_node)

    if use_nontree_edges
      MiniparInterpreter.each_reachable_node(from_node) { |node, ant, paths, prev|
        if node == to_node
          return paths.first
        end
        true # each_reachable_node requires boolean to determine
        # whether to continue the path beyond node
      }
    else
      return super(from_node, to_node)
    end
  end

  ###
  # surrounding_nodes:
  #
  # construct paths in syntactic structure between a node and each of its neighbors
  # path construction as in path_between.
  # Neighbors: parent, child, plus potentially neighbors by nontree edges
  # use_nontree_edges: again, same as in path_between
  #
  # returns: list of pairs [neighbor(SynNode), path(Path)]
  def MiniparInterpreter.surrounding_nodes(node, # SynNode
                                           use_nontree_edges = false) # boolean
    normal_neighbors = super(node, use_nontree_edges)
    # add antecedents
    more_neighbors = Array.new
    normal_neighbors.each { |neighbor, path|
      while n = (neighbor.get_f("antecedent"))
        more_neighbors << [n, path]
        neighbor = n
      end
    }
    return normal_neighbors + more_neighbors
  end


  #   ###
  #   # main node of expression
  #   #
  #   # 2nd argument non-nil:
  #   # don't handle multiword expressions beyond verbs with separate particles
  #   #
  #   # returns: SynNode, main node, if found
  #   # else nil
  #   def MiniparInterpreter.main_node_of_expr(nodelist,
  #                                            no_mwes = nil)

  #     nodelist = nodelist.map { |n| MiniparInterpreter.ensure_upper(n) }.uniq()

  #     # main reason we are overwriting the parent method:
  #     # don't go to terminal nodes right away.
  #     # If we have a single nonterminal, stay with it.
  #     # Otherwise, use parent method
  #     if nodelist.length() == 1
  #       return nodelist.first
  #     end

  #     return super(nodelist, no_mwes)
  #   end

  ########
  # max constituents:
  # given a set of nodes, compute the maximal constituents
  # that exactly cover them
  #
  # overwrite default: ignore empty terminals, both in nodeset
  #  and in the nodes that are tested as potential maximal constituents
  def MiniparInterpreter.max_constituents(nodeset, # Array:SynNode
                                          sent,    # SalsaTigerSentence
                                          idealize_maxconst = false) # boolean

    my_nodeset = nodeset.reject { |n| MiniparInterpreter.empty_terminal?(n)}
    if idealize_maxconst
      return sent.max_constituents_smc(my_nodeset, idealize_maxconst, true)
    else
      return sent.max_constituents_for_nodes(my_nodeset, true)
    end
  end


  ###
  # for all nodes reachable from a given from_node:
  # compute the path from from_node,
  # using both tree edges and coreference edges
  #
  # compute a widening circle of nodes from from_node outward,
  # following all antecedent links as 0-length paths.
  #
  # yields tuples
  #  [
  #   minipar node,
  #   array: other minipar node(s) reached from this one solely via antecedent edges,
  #   array: minimal paths from start_node to this node as Path objects
  #   minipar node 2: last stop on path from start_node to minipar_node
  #  ]
  def MiniparInterpreter.each_reachable_node(from_node)   # SynNode

    from_node = MiniparInterpreter.ensure_upper(from_node)

    # rim: array:SynNode, current outermost nodes
    rim = [ from_node ]
    # seen: hash SynNode->Path, mapping (seen) minipar nodes to
    # the path leading from the target to them
    seen = {
      from_node => [Path.new(from_node)]
    }

    while not(rim.empty?)
      # remove node from the beginning of the rim
      minipar_node = rim.shift()

      # make tuples:
      # ["D" for down from minipar_node, or "U" for up,
      #  parent or child of minipar_node,
      #  edgelabel between minipar_node and that parent or child,
      #  POS of that parent or child,
      #  preposition
      #  ]
      surrounding_n = minipar_node.children.map { |child|
        ["D", child,
         minipar_node.child_label(child), child.part_of_speech()]
      }
      if minipar_node.parent
        surrounding_n.push([
                             "U", minipar_node.parent,
                             minipar_node.parent_label(),
                             minipar_node.parent.part_of_speech()
                           ])
      end

      surrounding_n.each { |direction, new_node, edgelabel, nodelabel|

        # node we are actually using: the antecedent, if it's there
        # the coref chain may have a length > 1
        actual_new_node = new_node
        antecedents = []
        while actual_new_node.get_f("antecedent")
          antecedents << actual_new_node.get_f("antecedent")
          actual_new_node = actual_new_node.get_f("antecedent")
        end

        # node seen before, and  seen with shorter path?
        # all paths in seen[actual_new_node] have the same length
        if seen[actual_new_node] and
          seen[actual_new_node].first.length() < seen[minipar_node].first.length() + 1
          # yes, seen with a shorter path. discard
          next
        end

        # make paths for this new_node
        paths = seen[minipar_node].map { |previous_path|
          new_path = previous_path.deep_clone
          if new_node.part_of_speech() == "Prep"
            # preposition? add to path too
            new_path.add_last_step(direction,
                                   edgelabel + "-" + new_node.get_attribute("lemma"),
                                   nodelabel,
                                   new_node)
          else
            new_path.add_last_step(direction, edgelabel, nodelabel, new_node)
          end
          new_path
        }

        # node not seen before: record
        unless seen[actual_new_node]
          seen[actual_new_node] = Array.new
        end
        seen[actual_new_node].concat paths

        keepthisnode = yield(new_node, antecedents, paths, minipar_node)

        if keepthisnode and not(rim.include?(actual_new_node))
          rim.push actual_new_node
        end

      } # each parent or child of the current rim node
    end # while new rim nodes keep being discovered
  end

  #####################33
  private

  ###
  # auxiliaries and modals share this characteristic
  def MiniparInterpreter.aux_or_modal?(node)
    node = MiniparInterpreter.ensure_upper(node)

    if (l = node.parent_label) and
      ["be", "have", "aux"].include? l and
      (p = node.parent) and
      MiniparInterpreter.category(p) == "verb"
      return true
    else
      return false
    end
  end

  ###
  # given a node: if it has a Head child, return that,
  # else return the node
  def MiniparInterpreter.ensure_terminal(node)
    headchildren = node.children_by_edgelabels(["Head"])
    if headchildren and not(headchildren.empty?)
      return headchildren.first
    else
      return node
    end
  end

  ###
  # given a node: if it is a terminal that is linked to its
  # parent by a Head edge, return the parent,
  # else return the node
  def MiniparInterpreter.ensure_upper(node)
    if node.parent_label() == "Head"
      return node.parent
    else
      return node
    end
  end

  ###
  # is this an empty terminal?
  def MiniparInterpreter.empty_terminal?(node)
    if node.is_terminal? and node.word().empty?
      return true
    else
      return false
    end
  end

end
