# frprep
# Katrin Erk July 05
#
# Preprocessing for Fred and Rosy:
# accept input as plain text,
# FrameNet XML, Salsa-tabular format,
# or SalsaTigerXML,
# lemmatize, POS-tag and parse
# (if asked to do so)
# and in any case produce output in
# SalsaTigerXML.
#
# Extensions to SalsaTigerXML introduced by frprep:
#
# - "lemma": lemma. Attribute of terminals.
# - "head":  head word (not lemma!) of constituent.Attribute of nonterminals.
# - "fn_gf": FrameNet grammatical function label, attached to the maximal
#   constituents covering the terminals labeled with that label

##################################

$LOAD_PATH.unshift('lib/frprep', 'lib/common')


# external packages
require "getoptlong"

# general packages provided by Salsa
require 'Ampersand'
require 'FNDatabase'
require 'FNCorpusXML'
require 'SalsaTigerRegXML'
require 'StandardPkgExtensions'

# Fred-, Rosy- and Frprep-specific packages
require 'FrPrepConfigData'
require 'FrprepHelper'
require 'SynInterfaces'
require 'FixSynSemMapping'

##############################
# help text

def help()
  $stderr.puts "
FrPrep: Preprocessing for Fred and Rosy
(i.e. for frame/word sense assignment and semantic role assignment)
  
Usage:
----------------

ruby frprep.rb --help|-h
  Gets you this text.


ruby frprep.rb --expfile|-e <e>
  Preprocess data according to the specifications
  of experiment file <e>.

  <e>: path to experiment file

  For specifics on the contents of the experiment file,
  see the file SAMPLE_EXPERIMENT_FILE in this directory.

"
end 

##############################
# class for managing the parses of one file
class OneParsedFile
  attr_reader :filename

  def initialize(filename,   # string: core of filename for the parse file
		 complete_filename, # string: complete filename of parse file
		 obj_with_iterator) # object with each_sentence method, see above
    @obj_with_iterator = obj_with_iterator
    @filename = filename
    @complete_filename = complete_filename
  end

  # yield each parse sentence as a tuple
  # [ salsa/tiger xml sentence, tab format sentence, mapping]
  # of a SalsaTigerSentence object, a FNTabSentence object,
  # and a hash: FNTab sentence lineno(integer) -> array:SynNode
  # pointing each tab word to one or more SalsaTigerSentence terminals
  def each_sentence()
    @obj_with_iterator.each_sentence(@complete_filename) { |st_sent, tab_sent, mapping|
      yield [st_sent, tab_sent, mapping]
    }  
  end
end

##############################
# class for managing parses:
#
# Given either a directory with tab format files or
# a directory with SalsaTigerXML files (or both) and 
# a directory for putting parse files:
# - parse, unless no parsing set in the experiment file
# - for each parsed file: yield one OneParsedFile object
class DoParses
  def initialize(exp,           # FrPrepConfigData object
		 file_suffixes, # hash: file type(string) -> suffix(string)
		 parse_dir,     # string: name of directory to put parses
		 var_hash = {}) # further directories
    @exp = exp
    @file_suffixes = file_suffixes
    @parse_dir = parse_dir
    @tab_dir = var_hash["tab_dir"]
    @stxml_dir = var_hash["stxml_dir"]

    # pre-parsed data available? 
    @parsed_files = @exp.get("directory_parserout")
  end

  ###
  def each_parsed_file()
    if @exp.get("do_postag") 
      postag_suffix = @file_suffixes["pos"] 
    else
      postag_suffix = nil
    end

    if @exp.get("do_lemmatize")
      lemma_suffix = @file_suffixes["lemma"] 
    else
      lemma_suffix = nil
    end

    if @exp.get("do_parse")

      # get parser interface
      sys_class = SynInterfaces.get_interface("parser", 
 					      @exp.get("parser"))
      unless sys_class
        raise "Shouldn't be here"
      end
      parse_suffix = "." + sys_class.name()
      sys = sys_class.new(@exp.get("parser_path"),
 			  @file_suffixes["tab"],
 			  parse_suffix,
 			  @file_suffixes["stxml"],
 			  "pos_suffix" => postag_suffix,
 			  "lemma_suffix" => lemma_suffix,
 			  "tab_dir" => @tab_dir)

      if @parsed_files
        # reuse old parses
        
        $stderr.puts "Frprep: using pre-computed parses in " + @parsed_files.to_s()
        $stderr.puts "Frprep: Postprocessing SalsaTigerXML data"
        
        Dir[@parsed_files + "*"].each { |parsefilename|
          
          if File.stat(parsefilename).ftype != "file"
            # something other than a file
            next
          end
          
          
          # core filename: remove directory and anything after the last "."
          filename_core = File.basename(parsefilename, ".*")
          #print "FN ", filename_core, " PN ", parsefilename, " sys ", sys, "\n"
          # use iterator to read each parsed file
          yield OneParsedFile.new(filename_core, parsefilename, sys)
        }

      else
        # do new parses
        $stderr.puts "Frprep: Parsing"
        
        # sanity check
        unless @exp.get("parser_path")
          raise "Parsing: I need 'parser_path' in the experiment file"
        end
        unless @tab_dir
          raise "Cannot parse without tab files"
        end

        # parse
        sys.process_dir(@tab_dir, @parse_dir)

        $stderr.puts "Frprep: Postprocessing SalsaTigerXML data"

        Dir[@parse_dir + "*" + parse_suffix].each { |parsefilename|
          filename_core = File.basename(parsefilename, parse_suffix)

          # use iterator to read each parsed file
          yield OneParsedFile.new(filename_core, parsefilename, sys)
        }
      end

    else
      # no parse:
      # get pseudo-parse tree

      if @stxml_dir
        # use existing SalsaTigerXML files
        Dir[@stxml_dir + "*.xml"].each { |stxmlfilename|

          filename_core = File.basename(stxmlfilename, ".xml")
          if @tab_dir
            # we know the tab directory too
            tabfilename = @tab_dir + filename_core + @file_suffixes["tab"]
            each_sentence_obj = FrprepReadStxml.new(stxmlfilename, tabfilename,
                                                    postag_suffix, lemma_suffix)
          else
            # we have no tab directory
            each_sentence_obj = FrprepReadStxml.new(stxmlfilename, nil,
                                                    postag_suffix, lemma_suffix)
          end

          yield OneParsedFile.new(filename_core, stxmlfilename, each_sentence_obj)
        }

      else
        # construct SalsaTigerXML from tab files
        Dir[@tab_dir+"*"+@file_suffixes["tab"]].each { |tabfilename|
          each_sentence_obj = FrprepFlatSyntax.new(tabfilename,
                                                   postag_suffix, 
                                                   lemma_suffix)
          filename_core = File.basename(tabfilename, @file_suffixes["tab"])
          yield OneParsedFile.new(filename_core, tabfilename, each_sentence_obj)
        }
      end # source of pseudo-parse
    end # parse or no parse
  end 
end


##############################
# The class that does all the work

class FrPrep

  def initialize(exp)   # FrprepConfigData object
    @exp = exp

    # remove previous contents of frprep internal data directory
    unless exp.get("frprep_directory")
      raise "Please set 'frprep_directory', the frprep internal data directory,\n" +
            "in the experiment file."
    end

    # experiment directory: 
    # frprep internal data directory, subdir according to experiment ID
     exp_dir = File.new_dir(@exp.get("frprep_directory"),
                            @exp.get("prep_experiment_ID"))
    # %x{rm -rf #{exp_dir}}

    # suffixes for different types of output files
    @file_suffixes = {"lemma" => ".lemma",
      "pos" => ".pos",
      "tab" => ".tab",
      "stxml" => ".xml"}
  end
  
  def transform()
    
    current_format = @exp.get("format")

    unless @exp.get("directory_input")
      $stderr.puts "Please specify 'directory_input' in the experiment file."
      exit 1
    end
    unless @exp.get("directory_preprocessed")
      $stderr.puts "Please specify 'directory_preprocessed' in the experiment file."
      exit 1
    end

    ##
    # input and output directories.
    #
    # sanity check: output in tab format will not work
    # if we also do a parse
    if @exp.get("tabformat_output") and @exp.get("do_parse")
      $stderr.puts "Error: Cannot do Tab format output"
      $stderr.puts "when the input text is being parsed."
      $stderr.puts "Please set either 'tabformat_output' or 'do_parse' to false."
      exit 1
    end
    input_dir = File.existing_dir(@exp.get("directory_input"))
    output_dir = File.new_dir(@exp.get("directory_preprocessed"))
    if @exp.get("tabformat_output")
      split_dir = output_dir
    else
      split_dir = frprep_dirname("split", "new")
    end

    ####
    # transform data to UTF-8

    if ["iso", "hex"].include? @exp.get("encoding")
      # transform ISO -> UTF-8 or Hex -> UTF-8
      # write result to encoding_dir, 
      # then set encoding_dir to be the new input_dir

      encoding_dir = frprep_dirname("encoding", "new")
      $stderr.puts "Frprep: Transforming  to UTF-8."
      Dir[input_dir + "*"].each { |filename|
        unless File.file? filename
          # not a file? then skip
          next
        end
        outfilename = encoding_dir + File.basename(filename)
        FrprepHelper.to_utf8_file(filename, outfilename, @exp.get("encoding"))
      }
      
      input_dir = encoding_dir
    end

    
    ####
    # transform data all the way to the output format,
    # which is SalsaTigerXML by default,
    # except when tabformat_output has been set, in which case it's 
    # Tab format.
    current_dir = input_dir

    if @exp.get("tabformat_output")
      done_format = "SalsaTabWithPos"
    else
      done_format = "Done"
    end

    while not(current_format == done_format)
      case current_format

      when "BNC"
        # basically plain, plus some tags to be removed
        plain_dir = frprep_dirname("plain", "new")
        
        $stderr.puts "Frprep: Transforming BNC format text in #{current_dir} to plain format."
        $stderr.puts "Storing the result in #{plain_dir}."
        $stderr.puts "Expecting one sentence per line."
        
	transform_bncformat_dir(current_dir, plain_dir)
        
	current_dir = plain_dir
	current_format = "Plain"

      when "Plain" 
	# transform to tab format
        
        tab_dir = frprep_dirname("tab", "new")

        $stderr.puts "Frprep: Transforming plain text in #{current_dir} to SalsaTab format."
        $stderr.puts "Storing the result in #{tab_dir}."
        $stderr.puts "Expecting one sentence per line."
        
	transform_plain_dir(current_dir, tab_dir)
        
	current_dir = tab_dir
	current_format = "SalsaTab"

      when "FNXml"
	# transform to tab format

        tab_dir = frprep_dirname("tab", "new")

	$stderr.puts "Frprep: Transforming FN data in #{current_dir} to tabular format."
	$stderr.puts "Storing the result in " + tab_dir

	fndata = FNDatabase.new(current_dir)
	fndata.extract_everything(tab_dir)
	Kernel.system("chmod -R g+rx #{tab_dir}")

	current_dir = tab_dir
	current_format = "SalsaTab"

      when "FNCorpusXml"
        # transform to tab format
        tab_dir = frprep_dirname("tab", "new")

	$stderr.puts "Frprep: Transforming FN data in #{current_dir} to tabular format."
	$stderr.puts "Storing the result in " + tab_dir
        # assuming that all XML files in the current directory are FN Corpus XML files
        Dir[current_dir + "*.xml"].each { |fncorpusfilename|
          corpus = FNCorpusXMLFile.new(fncorpusfilename)
          outfile = File.new(tab_dir + File.basename(fncorpusfilename, ".xml") + ".tab", 
                             "w")
          corpus.print_conll_style(outfile)
          outfile.close()
        }

	Kernel.system("chmod -R g+rx #{tab_dir}")
	current_dir = tab_dir
	current_format = "SalsaTab"

      when "SalsaTab"
	# lemmatize and POStag

        $stderr.puts "Frprep: Lemmatizing and parsing text in #{current_dir}."
        $stderr.puts "Storing the result in #{split_dir}."
        transform_pos_and_lemmatize(current_dir, split_dir)

        current_dir = split_dir
	current_format = "SalsaTabWithPos"

      when "SalsaTabWithPos"
        # parse

        parse_dir = frprep_dirname("parse", "new")

        $stderr.puts "Frprep: Transforming tabular format text in #{current_dir} to SalsaTigerXML format."
        $stderr.puts "Storing the result in #{parse_dir}."

        transform_salsatab_dir(current_dir, parse_dir, output_dir)

        current_dir = output_dir
	current_format = "Done"

      when "SalsaTigerXML"
        
        parse_dir = frprep_dirname("parse", "new")
	print "Transform parser output into stxml\n"	
        transform_stxml_dir(parse_dir, split_dir, input_dir, output_dir, @exp)
        current_dir = output_dir
        current_format = "Done"

      else
	$stderr.puts "Unknown data format #{current_format}"
        $stderr.puts "Please check the 'format' entry in your experiment file."
        raise "Experiment file problem"
      end
    end

    $stderr.puts "Frprep: Done preprocessing."
  end
  
  ############################################################################3
  private
  ############################################################################3

  ###############
  # frprep_dirname:
  # make directory name for frprep-internal data
  # of a certain kind described in <subdir>
  #
  # frprep_directory has one subdirectory for each experiment ID,
  # and below that there is one subdir per subtask
  #
  # If this is a new directory, it is constructed,
  # if it should be an existing directory, its existence is  checked.
  def frprep_dirname(subdir,     # string: designator of subdirectory
                     new = nil)  # non-nil: this may be a new directory

    dirname = File.new_dir(@exp.get("frprep_directory"),
                           @exp.get("prep_experiment_ID"),
                           subdir)


    if new
      return File.new_dir(dirname)
    else
      return File.existing_dir(dirname)
    end
  end
  


  ###############
  # transform_plain:
  #
  # transformation for BNC format:
  #
  # transform to plain format, removing <> elements
  def transform_bncformat_dir(input_dir,  # string: input directory
                              output_dir) # string: output directory

    Dir[input_dir + "*"].each { |bncfilename|
      
      # open input and output file
      # end output file name in "tab" because that is, at the moment, required
      outfilename = output_dir + File.basename(bncfilename)
      FrprepHelper.bnc_to_plain_file(bncfilename, outfilename)
    }
  end


  ###############
  # transform_plain:
  #
  # transformation for plaintext:
  #
  # transform to Tab format, separating punctuation from adjacent words
  def transform_plain_dir(input_dir,  # string: input directory
                          output_dir) # string: output directory

    Dir[input_dir + "*"].each { |plainfilename|
      
      # open input and output file
      # end output file name in "tab" because that is, at the moment, required
      outfilename = output_dir + File.basename(plainfilename) + @file_suffixes["tab"]
      FrprepHelper.plain_to_tab_file(plainfilename, outfilename)
    }
  end

  ###############
  # transform_pos_and_lemmatize
  #
  # transformation for Tab format files:
  #
  # - Split into parser-size chunks
  # - POS-tag, lemmatize
  def transform_pos_and_lemmatize(input_dir, # string: input directory
                                  output_dir) # string: output directory
    ##
    # split the TabFormatFile into chunks of max_sent_num size
    FrprepHelper.split_dir(input_dir, output_dir,@file_suffixes["tab"],
			   @exp.get("parser_max_sent_num"), 
			   @exp.get("parser_max_sent_len"))
    
    ##
    # POS-Tagging
    if @exp.get("do_postag")
      $stderr.puts "Frprep: Tagging."
      unless @exp.get("pos_tagger_path") and @exp.get("pos_tagger")
	raise "POS-tagging: I need 'pos_tagger' and 'pos_tagger_path' in the experiment file."
      end
      
      sys_class = SynInterfaces.get_interface("pos_tagger", 
					      @exp.get("pos_tagger"))
      print "pos tagger interface: ", sys_class, "\n" 
      unless sys_class
        raise "Shouldn't be here"
      end
      sys = sys_class.new(@exp.get("pos_tagger_path"),
			  @file_suffixes["tab"],
			  @file_suffixes["pos"])
      sys.process_dir(output_dir, output_dir)
    end
      
    
    ## 
    # Lemmatization
    if @exp.get("do_lemmatize")
      $stderr.puts "Frprep: Lemmatizing."
      unless @exp.get("lemmatizer_path") and @exp.get("lemmatizer")
	raise "Lemmatization: I need 'lemmatizer' and 'lemmatizer_path' in the experiment file."
      end

      sys_class = SynInterfaces.get_interface("lemmatizer", 
					      @exp.get("lemmatizer"))
      unless sys_class
        raise "Shouldn't be here"
      end
      sys = sys_class.new(@exp.get("lemmatizer_path"),
			  @file_suffixes["tab"],
			  @file_suffixes["lemma"])
      sys.process_dir(output_dir, output_dir)
    end
  end

  ###############
  # transform_salsatab
  #
  # transformation for Tab format files:
  #
  # - parse
  # - Transform parser output to SalsaTigerXML
  #   If no parsing, make flat syntactic structure.
  def transform_salsatab_dir(input_dir,        # string: input directory
                             parse_dir,     # string: output directory for parses 
                             output_dir)       # string: global output directory
    
    ##
    # (Parse and) transform to SalsaTigerXML 

    # get interpretation class for this 
    # parser/lemmatizer/POS tagger combination
    interpreter_class = SynInterfaces.get_interpreter_according_to_exp(@exp)
    unless interpreter_class
      raise "Shouldn't be here"
    end
    
    parse_obj = DoParses.new(@exp, @file_suffixes,
			     parse_dir, 
			     "tab_dir" => input_dir)
    parse_obj.each_parsed_file { |parsed_file_obj|

      outfilename = output_dir + parsed_file_obj.filename + ".xml"
      $stderr.puts "Writing #{outfilename}"
      begin
        outfile = File.new(outfilename, "w")
      rescue
        raise "Cannot write to SalsaTigerXML output file #{outfilename}"
      end

      outfile.puts SalsaTigerXMLHelper.get_header()
      # work with triples
      # SalsaTigerSentence, FNTabSentence,
      # hash: tab sentence index(integer) -> array:SynNode
      parsed_file_obj.each_sentence { |st_sent, tabformat_sent, mapping|

        # parsed: add headwords using parse tree
        if @exp.get("do_parse")
          FrprepHelper.add_head_attributes(st_sent, interpreter_class)
        end

        # add lemmas, if they are there. If they are not, don't print out a warning.
        if @exp.get("do_lemmatize")
          FrprepHelper.add_lemmas_from_tab(st_sent, tabformat_sent, mapping)
        end
        
        # add semantics
	# we can use the method in SalsaTigerXMLHelper
	# that reads semantic information from the tab file
	# and combines all targets of a sentence into one frame
	FrprepHelper.add_semantics_from_tab(st_sent, tabformat_sent, mapping, 
					    interpreter_class, @exp)

        # remove pseudo-frames from FrameNet data
        FrprepHelper.remove_deprecated_frames(st_sent, @exp)

        # handle multiword targets
        FrprepHelper.handle_multiword_targets(st_sent, 
					      interpreter_class, @exp.get("language"))

        # handle Unknown frame names
        FrprepHelper.handle_unknown_framenames(st_sent, interpreter_class)	       
	
        outfile.puts st_sent.get()
      }
      outfile.puts SalsaTigerXMLHelper.get_footer()
    }
  end

  #############################################
  # transform_stxml
  # 
  # transformation for SalsaTigerXML data
  #
  # - If the input format was SalsaTigerXML:
  #   - Tag, lemmatize and parse, if the experiment file tells you so
  #
  # - If the origin is the Salsa corpus: 
  #   Change frame names from Unknown\d+ to lemma_Unknown\d+
  #
  # - fix multiword lemmas, or at least try
  # - transform to UTF 8
  def transform_stxml_dir(parse_dir,  # string: name of directory for parse data
                          tab_dir,    # string: name of directory for split/tab data
                          input_dir,  # string: name of input directory
                          output_dir, # string: name of final output directory
                          exp)        # FrprepConfigData

    ####
    # Data preparation
    
    # Data with Salsa as origin:
    # remember the target lemma as an attribute on the 
    # <target> elements
    #
    # currently deactivated: encoding problems
    #     if @exp.get("origin") == "SalsaTiger"
    #       $stderr.puts "Frprep: noting target lemmas"
    #       changed_input_dir = frprep_dirname("salsalemma", "new") 
    #       FrprepHelper.note_salsa_targetlemmas(input_dir, changed_input_dir)     
    
    #       # remember changed input dir as input dir
    #       input_dir = changed_input_dir
    #     end
    
    #  If data is to be parsed, split and tabify input files
    #    else copy data to stxml_indir.
    
    # stxml_dir: directory where SalsaTiger data is situated
    if @exp.get("do_parse")
      # split data
      stxml_splitdir = frprep_dirname("stxml_split", "new")
      stxml_dir = stxml_splitdir

      $stderr.puts "Frprep: splitting data"
      FrprepHelper.stxml_split_dir(input_dir, stxml_splitdir, 
				   @exp.get("parser_max_sent_num"), 
				   @exp.get("parser_max_sent_len"))
    else
      # no parsing: copy data to split dir
      stxml_dir = parse_dir
      $stderr.puts "Frprep: Copying data to #{stxml_dir}"
      Dir[input_dir + "*.xml"].each { |filename|
        `cp #{filename} #{stxml_dir}#{File.basename(filename)}`
      }
    end

    # Some syntactic processing will take place:
    # tabify data
    if @exp.get("do_parse") or @exp.get("do_lemmatize") or @exp.get("do_postag")      
      $stderr.puts "Frprep: making input for syn. processing" 
      
      Dir[stxml_dir+"*"+@file_suffixes["stxml"]].each { |stxmlfilename|
        
        tabfilename = tab_dir + File.basename(stxmlfilename,@file_suffixes["stxml"]) + @file_suffixes["tab"]
        FrprepHelper.stxml_to_tab_file(stxmlfilename, tabfilename, exp)
      }
    end
    
    ###
    # POS-tagging
    if @exp.get("do_postag")
      $stderr.puts "Frprep: Tagging."
      unless @exp.get("pos_tagger_path") and @exp.get("pos_tagger")
	raise "POS-tagging: I need 'pos_tagger' and 'pos_tagger_path' in the experiment file."
      end

      sys_class = SynInterfaces.get_interface("pos_tagger", 
					      @exp.get("pos_tagger"))
      unless sys_class
        raise "Shouldn't be here"
      end
      sys = sys_class.new(@exp.get("pos_tagger_path"),
			  @file_suffixes["tab"],
			  @file_suffixes["pos"])
      sys.process_dir(tab_dir, tab_dir)
    end

    ###
    # Lemmatization
    if @exp.get("do_lemmatize")
      $stderr.puts "Frprep: Lemmatizing."
      unless @exp.get("lemmatizer_path") and @exp.get("lemmatizer")
	raise "Lemmatization: I need 'lemmatizer' and 'lemmatizer_path' in the experiment file."
      end

      sys_class = SynInterfaces.get_interface("lemmatizer", 
					      @exp.get("lemmatizer"))
      unless sys_class
        raise "Shouldn't be here"
      end
      sys = sys_class.new(@exp.get("lemmatizer_path"),
			  @file_suffixes["tab"],
			  @file_suffixes["lemma"])
      sys.process_dir(tab_dir, tab_dir)
    end

    ###
    # Parsing, production of SalsaTigerXML output

    # get interpretation class for this 
    # parser/lemmatizer/POS tagger combination
    sys_class_names = Hash.new
    [["do_postag", "pos_tagger"],
      ["do_lemmatize", "lemmatizer"],
      ["do_parse", "parser"]].each { |service, system_name|
      if @exp.get(service)  # yes, perform this service
	sys_class_names[system_name] = @exp.get(system_name)
      end
    }
    interpreter_class = SynInterfaces.get_interpreter(sys_class_names)
    unless interpreter_class
      raise "Shouldn't be here"
    end

    parse_obj = DoParses.new(@exp, @file_suffixes,
			     parse_dir, 
			     "tab_dir" => tab_dir,
                             "stxml_dir" => stxml_dir)
    parse_obj.each_parsed_file { |parsed_file_obj|
      outfilename = output_dir + parsed_file_obj.filename + ".xml"
      $stderr.puts "Writing #{outfilename}"
      begin
        outfile = File.new(outfilename, "w")
      rescue
        raise "Cannot write to SalsaTigerXML output file #{outfilename}"
      end


      if @exp.get("do_parse")
        # read old SalsaTigerXML file
        # so we can integrate the old file's semantics later
        oldxml = Array.new # array of sentence strings
        # we assume that the old and the new file have the same name,
        # ending in .xml.
        oldxmlfile = FilePartsParser.new(stxml_dir + parsed_file_obj.filename + ".xml")
        oldxmlfile.scan_s { |sent_string|
          # remember this sentence by its ID
          oldxml << sent_string
        }
      end       

      outfile.puts SalsaTigerXMLHelper.get_header()
      index = 0
      # work with triples
      # SalsaTigerSentence, FNTabSentence,
      # hash: tab sentence index(integer) -> array:SynNode
      parsed_file_obj.each_sentence { |st_sent, tabformat_sent, mapping|

        # parsed? then integrate semantics and lemmas from old file
        if @exp.get("do_parse")
          oldsent_string = oldxml[index]
          index += 1
          if oldsent_string

            # modified by ines, 27/08/08
            # for Berkeley => substitute ( ) for *LRB* *RRB*
            if exp.get("parser") == "berkeley"
              oldsent_string.gsub!(/word='\('/, "word='*LRB*'")
              oldsent_string.gsub!(/word='\)'/, "word='*RRB*'")
              oldsent_string.gsub!(/word=\"\(\"/, "word='*LRB*'")
              oldsent_string.gsub!(/word=\"\)\"/, "word='*RRB*'")
            end

            # we have both an old and a new sentence, so integrate semantics
            oldsent = SalsaTigerSentence.new(oldsent_string)
	if st_sent.nil?
		next
	end
          if ( FrprepHelper.integrate_stxml_semantics_and_lemmas(oldsent, st_sent, interpreter_class, @exp) == false)
		#print "FALSE \n";
		#print oldsent, "\n", st_sent, "\n\n";

      	    	oldsent_string = oldxml[index]
        	index += 1
          	if oldsent_string

            	# modified by ines, 27/08/08
            	# for Berkeley => substitute ( ) for *LRB* *RRB*
            	if exp.get("parser") == "berkeley"
            	  oldsent_string.gsub!(/word='\('/, "word='*LRB*'")
            	  oldsent_string.gsub!(/word='\)'/, "word='*RRB*'")
            	  oldsent_string.gsub!(/word=\"\(\"/, "word='*LRB*'")
            	  oldsent_string.gsub!(/word=\"\)\"/, "word='*RRB*'")
            	end

            	# we have both an old and a new sentence, so integrate semantics
            	oldsent = SalsaTigerSentence.new(oldsent_string)
                #print oldsent, "\n", st_sent, "\n\n";
		FrprepHelper.integrate_stxml_semantics_and_lemmas(oldsent, st_sent, interpreter_class, @exp) 
	
		end
	  #else
			#print "TRUE\n";
			#print oldsent, "\n", st_sent, "\n\n";
 	  end
        else
            # no corresponding old sentence for this new sentence
            $stderr.puts "Warning: transporting semantics -- missing source sentence, skipping"
          end
        end

        # remove pseudo-frames from FrameNet data
        FrprepHelper.remove_deprecated_frames(st_sent, @exp)

        # repair syn/sem mapping problems?
        if @exp.get("fe_syn_repair") or @exp.get("fe_rel_repair")
          FixSynSemMapping.fixit(st_sent, @exp, interpreter_class)
        end

        outfile.puts st_sent.get()
      } # each ST sentence
      outfile.puts SalsaTigerXMLHelper.get_footer()
    } # each file parsed
  end


  ###################################
  # general file iterators

  # yields pairs of [infile name, outfile stream]
  def change_each_file_in_dir(dir,                 # string: directory name
                              suffix)    # string: filename pattern, e.g. "*.xml"
    Dir[dir + "*#{suffix}"].each { |filename|
      tempfile = Tempfile.new("FrprepHelper")
      yield [filename, tempfile]
      
      # move temp file to original file location
      tempfile.close()
      `cp #{filename} #{filename}.bak`
      `mv #{tempfile.path()} #{filename}`
      tempfile.close(true)
    } # each file
  end

  #######
  # change_each_stxml_file_in_dir
  #
  # use change_each_file_in_dir, but assume that the files
  # are SalsaTigerXML files: Keep file headers and footers,
  # and just offer individual sentences for changing
  #
  # Yields SalsaTigerSentence objects, each sentence to be changed
  def change_each_stxml_file_in_dir(dir)            # string: directory name

    change_each_file_in_dir(dir, "*.xml") { |stfilename, tf|
      infile = FilePartsParser.new(stfilename)

      # write header
      tf.puts infile.head()

      # iterate through sentences, yield as SalsaTigerSentence objects
      infile.scan_s() { |sent_string|
        sent = SalsaTigerSentence.new(sent_string)
        yield sent
        # write changed sentence
        tf.puts sent.get()
      } # each sentence
      
      # write footer
      tf.puts infile.tail()
      infile.close()
    }
  end
end


#######################################
# main starts here
######################################

#############
# preliminaries:

# evaluate runtime options
begin
  opts = GetoptLong.new([ '--expfile', '-e', GetoptLong::REQUIRED_ARGUMENT],
			[ '--help', '-h', GetoptLong::NO_ARGUMENT])
rescue
  $stderr.puts "Error: unknown command line option: " + $!
  exit 1
end


expfilename = nil

opts.each do |opt, arg|
  case opt
  when '--expfile'
    expfilename = File.expand_path(arg)
  when '--help'
    help()
    exit 0
  else
    help()
    exit 0
  end
end

unless expfilename
  raise "Please specify an experiment file, option --expfile|-e"
end

# read experiment file
exp = FrPrepConfigData.new(expfilename)

# sanity checks
unless exp.get("prep_experiment_ID") =~ /^[A-Za-z0-9_]+$/
  raise "Please choose an experiment ID consisting only of the letters A-Za-z0-9_."
end

SynInterfaces.check_interfaces_abort_if_missing(exp)

#############
# preprocessing

preprocessor =  FrPrep.new(exp)
preprocessor.transform()

