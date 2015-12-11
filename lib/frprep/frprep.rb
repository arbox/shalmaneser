require 'frprep/do_parses'
require 'common/prep_helper'
require 'common/FixSynSemMapping'
# For FN input.
require 'frprep/FNCorpusXML'
require 'frprep/FNDatabase'

require 'common/salsa_tiger_xml/salsa_tiger_sentence'

##############################
# The class that does all the work
module FrPrep
  class FrPrep
    # @param exp [FrprepConfigData] Configuration object
    def initialize(exp)
      @exp = exp

      # suffixes for different types of output files
      @file_suffixes = {"lemma" => ".lemma",
                        "pos" => ".pos",
                        "tab" => ".tab",
                        "stxml" => ".xml"}
    end

    # Main processing method.
    # @raise [ConfigurationError]
    def transform
      # experiment directory:
      # frprep internal data directory, subdir according to experiment ID
      # @todo Move it to a separate method.
      File.new_dir(@exp.get("frprep_directory"), @exp.get("prep_experiment_ID"))

      # input and output directories.
      #
      input_dir = File.existing_dir(@exp.get("directory_input"))
      output_dir = File.new_dir(@exp.get("directory_preprocessed"))

      if @exp.get("tabformat_output")
        split_dir = output_dir
      else
        split_dir = frprep_dirname("split", "new")
      end

      ####
      # @todo Use standard Ruby transcoding mechanics.
      # transform data to UTF-8
      if @exp.convert_encoding?
        # transform ISO -> UTF-8 or Hex -> UTF-8
        # write result to encoding_dir,
        # then set encoding_dir to be the new input_dir

        encoding_dir = frprep_dirname("encoding", "new")
        # @todo Introduce here the Logger.
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

      done_format = @exp.get("tabformat_output") ? 'SalsaTabWithPos' : 'Done'

      current_format = @exp.get("format")

      while current_format != done_format
        # AB: DEBUG Remove it
        STDERR.puts "#{current_format} - #{done_format}"
        # after debugging
        case current_format
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
            outfile.close
          }

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
          STDERR.puts "Done format is: #{done_format}"
          $stderr.puts "Unknown data format #{current_format}"
          $stderr.puts "Please check the 'format' entry in your experiment file."
          raise "Experiment file problem"
        end
      end

      STDERR.puts "FrPrep: Done preprocessing."
    end

    ############################################################################
    private

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
    # @param subdir [String] designator of a subdirectory
    # @param neu [Nil] non-nil This may be a new directory
    def frprep_dirname(subdir, neu = nil)

      dirname = File.new_dir(@exp.get("frprep_directory"),
                             @exp.get("prep_experiment_ID"),
                             subdir)

      neu ? File.new_dir(dirname) : File.existing_dir(dirname)
    end

    ###############
    # transform_plain:
    #
    # transformation for plaintext:
    #
    # transform to Tab format, separating punctuation from adjacent words
    # @param input_dir [String] input directory
    # @param output_dir [String] output directory
    def transform_plain_dir(input_dir, output_dir)
      Dir[input_dir + "*"].each do |plainfilename|
        # open input and output file
        # end output file name in "tab" because that is, at the moment, required
        outfilename = output_dir + File.basename(plainfilename) + @file_suffixes["tab"]
        FrprepHelper.plain_to_tab_file(plainfilename, outfilename)
      end
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
      FrprepHelper.split_dir(input_dir, output_dir, @file_suffixes["tab"],
                             @exp.get("parser_max_sent_num"),
                             @exp.get("parser_max_sent_len"))

      ##
      # POS-Tagging
      if @exp.get("do_postag")
        # @todo Introduct the Logger.
        $stderr.puts "Frprep: Tagging."

        sys_class = SynInterfaces.get_interface("pos_tagger",
                                                @exp.get("pos_tagger"))
        $stderr.puts "POS Tagger interface: #{sys_class}"

        # AB: TODO Remove it.
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
      # AB: We're working on the <split> dir and writing there.
      if @exp.get("do_lemmatize")
        STDERR.puts 'Frprep: Lemmatizing.'

        sys_class = SynInterfaces.get_interface("lemmatizer",
                                                @exp.get("lemmatizer"))
        # AB: TODO make this exception explicit.
        unless sys_class
          raise 'I got a empty interface class for the lemmatizer!'
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
    # @param [String] input_dir Input directory.
    # @param [String] parse_dir Output directory for parses.
    # @param [String] output_dir Global output directory.
    def transform_salsatab_dir(input_dir, parse_dir, output_dir)
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

        outfile.puts SalsaTigerXMLHelper.get_header
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
        outfile.puts SalsaTigerXMLHelper.get_footer
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

        Dir[stxml_dir + "*" + @file_suffixes["stxml"]].each do |stxmlfilename|

          tabfilename = tab_dir + File.basename(stxmlfilename,
                                                @file_suffixes["stxml"]) + @file_suffixes["tab"]
          FrprepHelper.stxml_to_tab_file(stxmlfilename, tabfilename, exp)
        end
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
      sys_class_names = {}

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
          # array of sentence strings
          oldxml = []

          # we assume that the old and the new file have the same name,
          # ending in .xml.
          oldxmlfile = FilePartsParser.new(stxml_dir + parsed_file_obj.filename + ".xml")
          oldxmlfile.scan_s { |sent_string|
            # remember this sentence by its ID
            oldxml << sent_string
          }
        end

        outfile.puts SalsaTigerXMLHelper.get_header
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
              # @note AB: Move this to the Berkeley Interface.
              if exp.get("parser") == "berkeley"
                oldsent_string.gsub!(/word='\('/, "word='*LRB*'")
                oldsent_string.gsub!(/word='\)'/, "word='*RRB*'")
                oldsent_string.gsub!(/word=\"\(\"/, "word='*LRB*'")
                oldsent_string.gsub!(/word=\"\)\"/, "word='*RRB*'")
              end

              # we have both an old and a new sentence, so integrate semantics
              oldsent = SalsaTigerSentence.new(oldsent_string)

              next if st_sent.nil?

              unless FrprepHelper.integrate_stxml_semantics_and_lemmas(oldsent,
                                                                    st_sent,
                                                                    interpreter_class,
                                                                    @exp)

                oldsent_string = oldxml[index]
                index += 1
                if oldsent_string

                  # modified by ines, 27/08/08
                  # for Berkeley => substitute ( ) for *LRB* *RRB*
                  # @note AB: Duplicated code!! Move it to the Berkeley Interface.
                  if exp.get("parser") == "berkeley"
                    oldsent_string.gsub!(/word='\('/, "word='*LRB*'")
                    oldsent_string.gsub!(/word='\)'/, "word='*RRB*'")
                    oldsent_string.gsub!(/word=\"\(\"/, "word='*LRB*'")
                    oldsent_string.gsub!(/word=\"\)\"/, "word='*RRB*'")
                  end

                  # we have both an old and a new sentence, so integrate semantics
                  oldsent = SalsaTigerSentence.new(oldsent_string)

                  FrprepHelper.integrate_stxml_semantics_and_lemmas(oldsent,
                                                                    st_sent,
                                                                    interpreter_class,
                                                                    @exp)
                end
              end
            else
              # no corresponding old sentence for this new sentence
              $stderr.puts "Warning: transporting semantics -- missing source sentence, skipping"
            end
          end

          # remove pseudo-frames from FrameNet data
          FrprepHelper.remove_deprecated_frames(st_sent, @exp)

          # repair syn/sem mapping problems?
          if @exp.get("fe_syn_repair") || @exp.get("fe_rel_repair")
            FixSynSemMapping.fixit(st_sent, @exp, interpreter_class)
          end

          outfile.puts st_sent.get
        } # each ST sentence
        outfile.puts SalsaTigerXMLHelper.get_footer
      } # each file parsed
    end


    ###################################
    # general file iterators

    # yields pairs of [infile name, outfile stream]
    # @param [String] dir Directory name.
    # @param [String] suffix Filename pattern, e.g. '*.xml'.
    def change_each_file_in_dir(dir, suffix)
      Dir[dir + "*#{suffix}"].each do |filename|
        tempfile = Tempfile.new("FrprepHelper")
        yield [filename, tempfile]

        # move temp file to original file location
        tempfile.close
        # @todo Use native Ruby methods.!!
        `cp #{filename} #{filename}.bak`
        `mv #{tempfile.path} #{filename}`
        tempfile.close(true)
      end
    end

    #######
    # change_each_stxml_file_in_dir
    #
    # use change_each_file_in_dir, but assume that the files
    # are SalsaTigerXML files: Keep file headers and footers,
    # and just offer individual sentences for changing
    #
    # Yields SalsaTigerSentence objects, each sentence to be changed
    # @param [String] dir Directory name.
    def change_each_stxml_file_in_dir(dir)
      change_each_file_in_dir(dir, "*.xml") do |stfilename, tf|
        infile = FilePartsParser.new(stfilename)

        # write header
        tf.puts infile.head

        # iterate through sentences, yield as SalsaTigerSentence objects
        infile.scan_s do |sent_string|
          sent = SalsaTigerSentence.new(sent_string)
          yield sent
          # write changed sentence
          tf.puts sent.get
        end # each sentence

        # write footer
        tf.puts infile.tail
        infile.close
      end
    end
  end
end
