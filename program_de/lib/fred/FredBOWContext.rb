require "tempfile"
require 'fileutils'

require "common/RegXML"
require "common/SynInterfaces"
require "common/TabFormat"
require "common/SalsaTigerRegXML"
require "common/SalsaTigerXMLHelper"

require 'fred/md5'
require "fred/FredConfigData"
require "fred/FredConventions"
require "fred/FredDetermineTargets"
require "common/DBInterface"
require "common/RosyConventions"
require "common/SQLQuery"

########################################
# Context Provider classes:
# read in text, collecting context windows of given size
# around target words, yield contexts as soon as they are complete
#
# Target words are determined by delegating to either TargetsFromFrames or AllTargets
# 
class AbstractContextProvider

  include WordLemmaPosNe

  ################
  def initialize(window_size, # int: size of context window (one-sided)
                 exp,         # experiment file object
                 interpreter_class, #SynInterpreter class
                 target_obj,  # AbstractTargetDeterminer object
                 dataset)     # "train", "test"

    @window_size = window_size
    @exp = exp
    @interpreter_class = interpreter_class
    @target_obj = target_obj
    @dataset = dataset

    # make arrays:
    # context words
    @context = Array.new(2 * @window_size + 1, nil)
    # nil for non-targets, all information on the target for targets
    @is_target = Array.new(2 * @window_size + 1, nil)
    # sentence object
    @sentence = Array.new(2 * @window_size + 1, nil)

  end

  ###################
  # each_window: iterator
  #
  # given a directory with Salsa/Tiger XML data,
  # iterate through the data, 
  # yielding each target word as soon as its context window is filled
  # (or the last file is at an end)
  #
  # yields tuples of:
  # - a context, an array of tuples [word,lemma, pos, ne]
  #   string/nil*string/nil*string/nil*string/nil
  # - ID of main target: string
  # - target_IDs: array:string, list of IDs of target words
  # - senses: array:string, the senses for the target
  # - sent: SalsaTigerSentence object
  def each_window(dir) # string: directory containing Salsa/Tiger XML data
    raise "overwrite me"
  end

  ####################
  protected

  ############################
  # shift a sentence through the @context window,
  # yield when at target
  #
  # yields tuples of:
  # - a context, an array of tuples [word,lemma, pos, ne]
  #   string/nil*string/nil*string/nil*string/nil
  # - ID of main target: string
  # - target_IDs: array:string, list of IDs of target words
  # - senses: array:string, the senses for the target
  # - sent: SalsaTigerSentence object
  def each_window_for_sent(sent)  # SalsaTigerSentence object or TabSentence object
  if sent.kind_of? SalsaTigerSentence
      each_window_for_stsent(sent) { |result| yield result }

    elsif sent.kind_of? TabFormatSentence
      each_window_for_tabsent(sent) { |result | yield result }

    else
      $stderr.puts "Error: got #{sent.class()}, expected SalsaTigerSentence or TabFormatSentence."
      exit 1
    end
  end

  ###
  # sent is a SalsaTigerSentence object:
  # there may be targets
  #
  # yields tuples of:
  # - a context, an array of tuples [word,lemma, pos, ne]
  #   string/nil*string/nil*string/nil*string/nil
  # - ID of main target: string
  # - target_IDs: array:string, list of IDs of target words
  # - senses: array:string, the senses for the target
  # - sent: SalsaTigerSentence object
  def each_window_for_stsent(sent)
    # determine targets first.
    # original targets:
    #  hash: target_IDs -> list of senses
    #   where target_IDs is a pair [list of terminal IDs, main terminal ID]
    #  
    #  where a sense is represented as a hash:
    #  "sense": sense, a string
    #  "obj":   FrameNode object
    #  "all_targets": list of node IDs, may comprise more than a single node
    #  "lex":   lemma, or multiword expression in canonical form
    #  "sid": sentence ID
    original_targets = @target_obj.determine_targets(sent)


    # reencode, make hashes:
    # main target ID -> list of senses,
    # main target ID -> all target IDs
    maintarget_to_senses = Hash.new()
    main_to_all_targets = Hash.new()
    original_targets.each_key { |alltargets, maintarget|

      main_to_all_targets[maintarget] = alltargets
      maintarget_to_senses[maintarget] = original_targets[[alltargets, maintarget]]

    }

    # then shift each terminal into the context window
    # and check whether there is a target at the center
    # position 
    sent_terminals_nopunct(sent).each { |term_obj|
      # add new word to end of context array
      @context.push(word_lemma_pos_ne(term_obj, @interpreter_class))

      if maintarget_to_senses.has_key? term_obj.id()
        @is_target.push( [ term_obj.id(),
                           main_to_all_targets[term_obj.id()],
                           maintarget_to_senses[term_obj.id()]
                         ]  )
      else
        @is_target.push(nil)
      end

      @sentence.push(sent)

      # remove first word from context array
      @context.shift()
      @is_target.shift()
      @sentence.shift()

      # check for target at center
      if @is_target[@window_size]
        # yes, we have a target at center position.
        # yield it:
        # - a context, an array of tuples [word,lemma, pos, ne]
        #   string/nil*string/nil*string/nil*string/nil
        # - ID of main target: string
        # - target_IDs: array:string, list of IDs of target words
        # - senses: array:string, the senses for the target
        # - sent: SalsaTigerSentence object
        main_target_id, all_target_ids, senses = @is_target[@window_size]

        yield [ @context, 
                main_target_id, all_target_ids,
                senses,
                @sentence[@window_size]
              ]
      end
    }
  end

  ###
  # sent is a TabFormatSentence object. 
  # shift word/lemma/pos/ne tuples throught the context window.
  # Whenever this brings a target (from another sentence, necessarily)
  # to the center of the context window, yield it.
  def each_window_for_tabsent(sent)
    sent.each_line_parsed() { |line_obj|
      # push onto the context array:
      # [word, lemma, pos, ne], all lowercase
      @context.push([ line_obj.get("word").downcase(),
                      line_obj.get("lemma").downcase(),
                      line_obj.get("pos").downcase(),
                      nil])
      @is_target.push(nil)
      @sentence.push(nil)

      # remove first word from context array
      @context.shift()
      @is_target.shift()
      @sentence.shift()

      # check for target at center
      if @is_target[@window_size]
        # yes, we have a target at center position.
        # yield it:
        # context window, main target ID, all target IDs, 
        # senses (as FrameNode objects), sentence as XML
        main_target_id, all_target_ids, senses = @is_target[@window_size]
        yield [ @context, 
                main_target_id, all_target_ids,
                senses,
                @sentence[@window_size]
              ]
      end
    }
  end

  ############################
  # each remaining target:
  # call this to empty the context window after everything has been shifted in
  def each_remaining_target()
    while @context.detect { |entry| not(entry.nil?) }
      # push nil on the context array
      @context.push(nil)
      @is_target.push(nil)
      @sentence.push(nil)

      # remove first word from context array
      @context.shift()
      @is_target.shift()
      @sentence.shift()
    
      # check for target at center
      if @is_target[@window_size]
        # yes, we have a target at center position.
        # yield it:
        # context window, main target ID, all target IDs, 
        # senses (as FrameNode objects), sentence as XML
        main_target_id, all_target_ids, senses = @is_target[@window_size]
        yield [ @context, 
                main_target_id, all_target_ids,
                senses,
                @sentence[@window_size]
              ]
      end
    end
  end
  ############################
  # helper: remove punctuation
  def sent_terminals_nopunct(sent)
    return sent.terminals_sorted.reject { |node| 
      @interpreter_class.category(node) == "pun"
    }
  end
end

####################################
# ContextProvider:
# subclass of AbstractContextProvider
# that assumes that the input text is a contiguous text
# and computes the context accordingly.
class ContextProvider < AbstractContextProvider
  ###
  # each_window: iterator
  #
  # given a directory with Salsa/Tiger XML data,
  # iterate through the data, 
  # yielding each target word as soon as its context window is filled
  # (or the last file is at an end)
  def each_window(dir) # string: directory containing Salsa/Tiger XML data

    # iterate through files in the directory.
    # Try sorting filenames numerically, since this is
    # what frprep mostly does with filenames
    Dir[dir + "*.xml"].sort { |a, b|
      File.basename(a, ".xml").to_i() <=> File.basename(b, ".xml").to_i()
    }.each { |filename|

      # progress bar
      if @exp.get("verbose")
        $stderr.puts "Featurizing #{File.basename(filename)}"
      end
      f = FilePartsParser.new(filename)
      each_window_for_file(f) { |result|
    	  yield result
      }
    }    
    # and empty the context array
    each_remaining_target() { |result| yield result }
  end

  ##################################
  protected

  ######################
  # each_window_for_file: iterator
  # same as each_window, but only for a single file
  # (to be called from each_window())
  def each_window_for_file(fpp) # FilePartsParser object: Salsa/Tiger XMl data
    fpp.scan_s() { |sent_string|
      sent = SalsaTigerSentence.new(sent_string)
      each_window_for_sent(sent) { |result| yield result }
    }
  end
end

####################################
# SingleSentContextProvider:
# subclass of AbstractContextProvider
# that assumes that each sentence of the input text
# stands on its own
class SingleSentContextProvider < AbstractContextProvider
  ###
  # each_window: iterator
  #
  # given a directory with Salsa/Tiger XML data,
  # iterate through the data, 
  # yielding each target word as soon as its context window is filled
  # (or the last file is at an end)
  def each_window(dir) # string: directory containing Salsa/Tiger XML data
    # iterate through files in the directory.
    # Try sorting filenames numerically, since this is
    # what frprep mostly does with filenames
    Dir[dir + "*.xml"].sort { |a, b|
      File.basename(a, ".xml").to_i() <=> File.basename(b, ".xml").to_i()
    }.each { |filename|
      # progress bar
      if @exp.get("verbose")
        $stderr.puts "Featurizing #{File.basename(filename)}"
      end
      f = FilePartsParser.new(filename)
      each_window_for_file(f) { |result|
        yield result
      }
    }    
  end

  ##################################
  protected


  ######################
  # each_window_for_file: iterator
  # same as each_window, but only for a single file
  # (to be called from each_window())
  def each_window_for_file(fpp) # FilePartsParser object: Salsa/Tiger XMl data
    fpp.scan_s() { |sent_string|
      sent = SalsaTigerSentence.new(sent_string)

      each_window_for_sent(sent) { |result| 
        yield result 
      }
    }
    # no need to clear the context: we're doing this after each sentence
  end

  ###
  # each_window_for_sent: empty context after each sentence
  def each_window_for_sent(sent)
    if sent.kind_of? SalsaTigerSentence
      each_window_for_stsent(sent) { |result| yield result }

    elsif sent.kind_of? TabFormatSentence
      each_window_for_tabsent(sent) { |result | yield result }

    else
      $stderr.puts "Error: got #{sent.class()}, expected SalsaTigerSentence or TabFormatSentence."
      exit 1
    end
    
    # clear the context
    each_remaining_target() { |result| yield result }
  end
end


####################################
# NoncontiguousContextProvider:
# subclass of AbstractContextProvider
# 
# This class assumes that the input text consists of single sentences
# drawn from a larger corpus.
# It first constructs an index to the sentences of the input text,
# then reads the larger corpus

class NoncontiguousContextProvider < AbstractContextProvider

  ###
  # each_window: iterator
  #
  # given a directory with Salsa/Tiger XML data,
  # iterate through the data and construct an index to the sentences.
  #
  # Then iterate through the larger corpus,
  # yielding contexts.
  def each_window(dir) # string: directory containing Salsa/Tiger XML data

    # sanity check: do we know where the larger corpus is?
    unless @exp.get("larger_corpus_dir")
      $stderr.puts "Error: 'noncontiguous_input' has been set in the experiment file"
      $stderr.puts "but no location for the larger corpus has been given."
      $stderr.puts "Please set 'larger_corpus_dir' in the experiment file"
      $stderr.puts "to indicate the larger corpus from which the input corpus sentences are drawn."
      exit 1
    end

    ##
    # remember all sentences from the main corpus
    temptable_obj, sentkeys = make_index(dir)

    ##
    # make frprep experiment file
    # for lemmatization and POS-tagging of larger corpus files
    tf_exp_frprep = Tempfile.new("fred_bow_context")
    frprep_in, frprep_out, frprep_dir = write_frprep_experiment_file(tf_exp_frprep)

    ##
    # Iterate through the files of the larger corpus,
    # check for each sentence whether it is also in the input corpus
    # and yield it if it does.
    # larger corpus may contain subdirectories
    initialize_match_check()

    each_infile(@exp.get("larger_corpus_dir")) { |filename|
      $stderr.puts "Larger corpus: reading #{filename}"

      # remove previous data from temp directories
      remove_files(frprep_in)
      remove_files(frprep_out)
      remove_files(frprep_dir)

      # link the input file to input directory for frprep
      File.symlink(filename, frprep_in + "infile")

      # call frprep
      retv = Kernel.system("ruby frprep.rb -e #{tf_exp_frprep.path()}")
      unless retv
        $stderr.puts "Error analyzing #{filename}. Exiting."
        exit 1
      end
      

      # read the resulting Tab format file, one sentence at a time:
      # - check to see if the checksum of the sentence is in sentkeys 
      #   (which means it is an input sentence)
      #   If it is, retrieve the sentence and determine targets
      # - shift the sentence through the context window
      # - whenever a target word comes to be in the center of the context window,
      #   yield.
      $stderr.puts "Computing context features from frprep output."
      Dir[frprep_out + "*.tab"].each { |tabfilename|
        tabfile = FNTabFormatFile.new(tabfilename, ".pos", ".lemma")
        tabfile.each_sentence() { |tabsent|
          
          # get as Salsa/Tiger XML sentence, or TabSentence
          sent = get_stxml_sent(tabsent, sentkeys, temptable_obj)

          # shift sentence through context window
          each_window_for_sent(sent) { |result| 
            yield result 
          }

        } # each tab sent
      } # each tab file
    } # each infile from the larger corpus

    # empty the context array
    each_remaining_target() { |result| yield result }
    each_unmatched(sentkeys, temptable_obj) { |result| yield result }
    
    # remove temporary data
    temptable_obj.drop_temp_table()
    %x{rm -rf #{frprep_in}}
    %x{rm -rf #{frprep_out}}
    %x{rm -rf #{frprep_dir}}
  end

  ##################################
  private

  ###
  # for each sentence of each file in the given directory:
  # remember the sentence in a temporary DB,
  # indexed by a hash key computed from the plaintext sentence.
  #
  # return: 
  # - DBTempTable object containing the temporary DB
  # - hash table containing all hash keys
  def make_index(dir)

    space_for_sentstring = 30000
    space_for_hashkey = 500

    $stderr.puts "Indexing input corpus:"

    # start temporary table
    temptable_obj = get_db_interface(@exp).make_temp_table([
                                                            ["hashkey", "varchar(#{space_for_hashkey})"], 
                                                            ["sent", "varchar(#{space_for_sentstring})"]
                                                           ],
                                                           ["hashkey"],
                                                           "autoinc_index")
    
    # and hash table for the keys
    retv_keys = Hash.new()

    # iterate through files in the directory,
    # make an index for each sentence, and store
    # the sentence under that index
    Dir[dir + "*.xml"].each { |filename|
      $stderr.puts "\t#{filename}"
      f = FilePartsParser.new(filename)
      f.scan_s() { |sent_string|

        xml_obj = RegXML.new(sent_string)

        # make hash key from words of sentence
        graph = xml_obj.children_and_text().detect { |c| c.name() == "graph" }
        unless graph
          next 
        end
        terminals = graph.children_and_text().detect { |c| c.name() == "terminals" }
        unless terminals
          next
        end
        # in making a hash key, use special characters
        # rather than their escaped &..; form
        # $stderr.puts "HIER calling checksum for noncontig"
        hashkey = checksum(terminals.children_and_text().select { |c| c.name() == "t" 
                           }.map { |t| 
                             SalsaTigerXMLHelper.unescape(t.attributes()["word"].to_s() )
                           })
        # HIER
        # $stderr.puts "HIER " + terminals.children_and_text().select { |c| c.name() == "t"
        # }.map { |t| t.attributes()["word"].to_s() }.join(" ")

        # sanity check: if the sentence is longer than
        # the space currently allotted to sentence strings,
        # we won't be able to recover it.
        if SQLQuery.stringify_value(hashkey).length() > space_for_hashkey
          $stderr.puts "Warning: sentence checksum too long, cannot store it."
          $stderr.print "Max length: #{space_for_hashkey}. "
          $stderr.puts "Required: #{SQLQuery.stringify_value(hashkey).length()}."
          $stderr.puts "Skipping."
          next
        end

        if SQLQuery.stringify_value(sent_string).length() > space_for_sentstring
          $stderr.puts "Warning: sentence too long, cannot store it."
          $stderr.print "Max length: #{space_for_sentstring}. "
          $stderr.puts "Required: #{SQLQuery.stringify_value(sent_string).length()}."
          $stderr.puts "Skipping."
          next
        end

        # store
        temptable_obj.query_noretv(SQLQuery.insert(temptable_obj.table_name,
                                                   [["hashkey", hashkey],
                                                    ["sent", sent_string]]))
        retv_keys[hashkey] = true
      }
    }    
    $stderr.puts "Indexing finished."

    return [ temptable_obj, retv_keys ]
  end

  ######
  # compute checksum from the given sentence,
  # and return as string
  def checksum(words) # array: string
    string = ""

    # HIER removed sort() after downcase
    words.map { |w| w.to_s.downcase }.each { |w|
      string << w.gsub(/[^a-z]/, "")
    }
    return MD5.new(string).hexdigest
  end

  #####
  # yield each file of the given directory
  # or one of its subdirectories
  def each_infile(indir)
    unless indir =~ /\/$/
      indir = indir + "/"
    end

    Dir[indir + "*"].each { |filename|
      if File.file?(filename)
        yield  filename
      end
    }

    # enter recursion
    Dir[indir + "**"].each { |subdir|
      # same directory we had before? don't redo
      if indir == subdir
        next
      end

      begin
        unless File.stat(subdir).directory? 
          next
        end
      rescue
        # no access, I assume
        next
      end
    
      each_infile(subdir) { |inf|
        yield inf
      }
    }
  end

  ###
  # remove files: remove all files and subdirectories in the given directory
  def remove_files(indir)
    Dir[indir + "*"].each { |filename|
      if File.file?(filename) or File.symlink?(filename)
        retv = File.delete(filename)
      end
    }

    # enter recursion
    Dir[indir + "**"].each { |subdir|
      # same directory we had before? don't redo
      if indir == subdir
        next
      end

      begin
        unless File.stat(subdir).directory? 
          next
        end
      rescue
        # no access, I assume
        next
      end
    
      # subdir must end in slash
      unless subdir =~ /\/$/
        subdir = subdir + "/"
      end
      # and enter recursion
      remove_files(subdir)
      File.rm_f(subdir)
    }
  end

  def write_frprep_experiment_file(tf_exp_frprep) # Tempfile object

    # make unique experiment ID
    experiment_id = "larger_corpus"
    # input and output directory for frprep
    frprep_in = fred_dirname(@exp, "temp", "in", "new")
    frprep_out = fred_dirname(@exp, "temp", "out", "new")
    frprep_dir = fred_dirname(@exp, "temp", "frprep", "new")

    # write file:

    # experiment ID and directories
    tf_exp_frprep.puts "prep_experiment_ID = #{experiment_id}"
    tf_exp_frprep.puts "directory_input = #{frprep_in}"
    tf_exp_frprep.puts "directory_preprocessed = #{frprep_out}"
    tf_exp_frprep.puts "frprep_directory = #{frprep_dir}"

    # output format: tab
    tf_exp_frprep.puts "tabformat_output = true"

    # corpus description: language, format, encoding
    if @exp.get("language")
      tf_exp_frprep.puts "language = #{@exp.get("language")}"
    end
    if @exp.get("larger_corpus_format")
      tf_exp_frprep.puts "format = #{@exp.get("larger_corpus_format")}"
    elsif @exp.get("format")
      $stderr.puts "Warning: 'larger_corpus_format' not set in experiment file,"
      $stderr.puts "using 'format' setting of frprep experiment file instead."
      tf_exp_frprep.puts "format = #{@exp.get("format")}"
    else
      $stderr.puts "Warning: 'larger_corpus_format' not set in experiment file,"
      $stderr.puts "relying on default setting."
    end
    if @exp.get("larger_corpus_encoding")
      tf_exp_frprep.puts "encoding = #{@exp.get("larger_corpus_encoding")}"
    elsif @exp.get("encoding")
      $stderr.puts "Warning: 'larger_corpus_encoding' not set in experiment file,"
      $stderr.puts "using 'encoding' setting of frprep experiment file instead."
      tf_exp_frprep.puts "encoding = #{@exp.get("encoding")}"
    else
      $stderr.puts "Warning: 'larger_corpus_encoding' not set in experiment file,"
      $stderr.puts "relying on default setting."
    end

    # processing: lemmatization, POS tagging, no parsing
    tf_exp_frprep.puts "do_lemmatize = true"
    tf_exp_frprep.puts "do_postag = true"
    tf_exp_frprep.puts "do_parse = false"

    # lemmatizer and POS tagger settings:
    # take verbatim from frprep file
    begin
      f = File.new(@exp.get("preproc_descr_file_" + @dataset))
    rescue
      $stderr.puts "Error: could not read frprep experiment file #{@exp.get("preproc_descr_file_" + @dataset)}"
      exit 1
    end
    f.each { |line|
      if line =~ /pos_tagger\s*=/ or
          line =~ /pos_tagger_path\s*=/ or
          line =~ /lemmatizer\s*=/ or
          line =~ /lemmatizer_path\s*=/

        tf_exp_frprep.puts line
      end
    }
    # finalize frprep experiment file
    tf_exp_frprep.close()

    return [frprep_in, frprep_out, frprep_dir]
  end

  ####
  # get SalsaTigerXML sentence and targets:
  #
  # given a Tab format sentence:
  # - check whether it is in the table of input sentences.
  #   if so, retrieve it.
  # - otherwise, fashion a makeshift SalsaTigerSentence object
  #   from the words, lemmas and POS
  def get_stxml_sent(tabsent,
                     sentkeys,
                     temptable_obj)

    # SalsaTigerSentence object
    sent = nil

    # make checksum
    words = Array.new()
    words2 = Array.new()
    tabsent.each_line_parsed { |line_obj|
      words << SalsaTigerXMLHelper.unescape(line_obj.get("word"))
      words2 << line_obj.get("word")
    }
    # $stderr.puts "HIER calling checksum from larger corpus"
    hashkey_this_sentence = checksum(words)

    # HIER
    # $stderr.puts "HIER2 " + words.join(" ")
    # $stderr.puts "HIER3 " + words2.join(" ")


    if sentkeys[hashkey_this_sentence]  
      # sentence from the input corpus.

      # register
      register_matched(hashkey_this_sentence)


      # select "sent" columns from temp table
      # where "hashkey" == sent_checksum
      # returns a DBResult object
      query_result = temptable_obj.query(SQLQuery.select([ SelectTableAndColumns.new(temptable_obj, ["sent"]) ], 
                                                       [ ValueRestriction.new("hashkey", hashkey_this_sentence) ]))
      query_result.each { |row|

        sent_string = SQLQuery.unstringify_value(row.first().to_s())
        begin
          sent = SalsaTigerSentence.new(sent_string)
        rescue
          $stderr.puts "Error reading Salsa/Tiger XML sentence."
          $stderr.puts
          $stderr.puts "SQL-stored sentence was:"
          $stderr.puts row.first().to_s()
          $stderr.puts
          $stderr.puts "==================="
          $stderr.puts "With restored quotes:"
          $stderr.puts sent_string
          exit 1
        end
        break
      }
      unless sent
        $stderr.puts "Warning: could not retrieve input corpus sentence: " + words.join(" ")
      end
    end

    if sent
      return sent
    else
      return tabsent
    end
  end

  ###
  # Keep track of which sentences from the smaller, noncontiguous corpus
  # have been matched in the larger corpus
  def initialize_match_check()
    @index_matched = Hash.new()
  end

  ###
  # Record a sentence from the smaller, noncontiguous corpus
  # as matched in the larger corpus
  def register_matched(hash_key)
    @index_matched[hash_key] = true
  end

  ###
  # Call this method after all sentences from the larger corpus
  # have been checked against the smaller corpus.
  # This method prints a warning message for each sentence from the smaller corpus
  # that has not been matched,
  # and yields it in the same format as each_window(),
  # such that the unmatched sentences can still be processed,
  # but without a larger context.
  def each_unmatched(all_keys,
                      temptable_obj)

    num_unmatched = 0

    all_keys.each_key { |hash_key|
      unless @index_matched[hash_key]
        # unmatched sentence:

        num_unmatched += 1

        # retrieve
        query_result = temptable_obj.query(SQLQuery.select([ SelectTableAndColumns.new(temptable_obj, ["sent"]) ], 
                                                           [ ValueRestriction.new("hashkey", hash_key) ]))

        # report and yield
        query_result.each { |row|

          sent_string = SQLQuery.unstringify_value(row.first().to_s())
          begin
            # report on unmatched sentence
            sent = SalsaTigerSentence.new(sent_string)
            $stderr.puts "Unmatched sentence from noncontiguous input:\n" + 
              sent.id().to_s() + " " + sent.to_s()

            # push the sentence through the context window,
            # filling it up with "nil",
            # and yield when we reach the target at center position.
            each_window_for_stsent(sent) { |result| yield result }
            each_remaining_target() { |result| yield result }

          rescue
            # Couldn't turn it into a SalsaTigerSentence object:
            # just report, don't yield
            $stderr.puts "Unmatched sentence from noncontiguous input (raw):\n" + 
              sent_string
            $stderr.puts "ERROR: cannot process this sentence, skipping."
          end
        }
      end
    }

    $stderr.puts "Unmatched sentences: #{num_unmatched} all in all."
  end

end
