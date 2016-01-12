require 'logging'

module Shalmaneser
  module Frappe
    class STXMLConverter
      def initialize(exp)
        @exp = exp
        # @todo Implement the logger as a mixin for all classes.
        @logger = LOGGER
        # suffixes for different types of output files
        @file_suffixes = {"lemma" => ".lemma", "pos" => ".pos", "tab" => ".tab", "stxml" => ".xml"}
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
      # string: name of directory for parse data
      # string: name of directory for split/tab data
      # string: name of input directory
      # string: name of final output directory
      # FrappeConfigData
      def transform_stxml_dir(parse_dir, tab_dir, input_dir, output_dir)
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
        #       FrappeHelper.note_salsa_targetlemmas(input_dir, changed_input_dir)

        #       # remember changed input dir as input dir
        #       input_dir = changed_input_dir
        #     end

        #  If data is to be parsed, split input files
        #    else copy data to stxml_indir.
        # stxml_dir: directory where SalsaTiger data is situated
        if @exp.get("do_parse")
          # split data
          stxml_splitdir = frprep_dirname("stxml_split", "new")
          stxml_dir = stxml_splitdir

          LOGGER.info "#{PROGRAM_NAME}: Splitting the input data into #{stxml_dir}."

          FrappeHelper.stxml_split_dir(input_dir, stxml_splitdir, @exp.get("parser_max_sent_num"), @exp.get("parser_max_sent_len"))
        else
          # no parsing: copy data to split dir
          stxml_dir = parse_dir

          LOGGER.info "#{PROGRAM_NAME}: Copying data to #{stxml_dir}"

          Dir[input_dir + "*.xml"].each { |f| FileUtils.cp(f, stxml_dir) }
        end

        # Some syntactic processing will take place:
        # tabify data
        if @exp.get("do_parse") || @exp.get("do_lemmatize") || @exp.get("do_postag")
          LOGGER.info "#{PROGRAM_NAME}: Making input for syn. processing."
          Dir[stxml_dir + "*" + @file_suffixes["stxml"]].each do |stxmlfilename|
            tabfilename = tab_dir + File.basename(stxmlfilename, @file_suffixes["stxml"]) + @file_suffixes["tab"]
            stxml_to_tab_file(stxmlfilename, tabfilename)
          end
        end

        ###
        # POS-tagging
        if @exp.get("do_postag")
          LOGGER.info "#{PROGRAM_NAME}: Tagging."
          sys_class = ExternalSystems.get_interface("pos_tagger", @exp.get("pos_tagger"))
          sys = sys_class.new(@exp.get("pos_tagger_path"), @file_suffixes["tab"], @file_suffixes["pos"])
          sys.process_dir(tab_dir, tab_dir)
        end

        ###
        # Lemmatization
        if @exp.get("do_lemmatize")
          LOGGER.info "#{PROGRAM_NAME}: Lemmatizing."
          sys_class = ExternalSystems.get_interface("lemmatizer", @exp.get("lemmatizer"))
          sys = sys_class.new(@exp.get("lemmatizer_path"), @file_suffixes["tab"], @file_suffixes["lemma"])
          sys.process_dir(tab_dir, tab_dir)
        end

        ###
        # Parsing, production of SalsaTigerXML output

        # get interpretation class for this
        # parser/lemmatizer/POS tagger combination
        sys_class_names = {}

        [["do_postag", "pos_tagger"], ["do_lemmatize", "lemmatizer"], ["do_parse", "parser"]].each do |service, system_name|
          # yes, perform this service
          if @exp.get(service)
            sys_class_names[system_name] = @exp.get(system_name)
          end
        end

        interpreter_class = ExternalSystems.get_interpreter(sys_class_names)

        unless interpreter_class
          raise "Shouldn't be here"
        end

        parse_obj = FileParser.new(@exp, @file_suffixes, parse_dir, "tab_dir" => tab_dir, "stxml_dir" => stxml_dir)
        parse_obj.each_parsed_file do |parsed_file_obj|
          outfilename = output_dir + parsed_file_obj.filename + ".xml"
          LOGGER.debug "Writing #{outfilename}."
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
            oldxmlfile = STXML::FilePartsParser.new(stxml_dir + parsed_file_obj.filename + ".xml")
            oldxmlfile.scan_s do |sent_string|
              # remember this sentence by its ID
              oldxml << sent_string
            end
          end
          outfile.puts STXML::SalsaTigerXMLHelper.get_header
          index = 0
          # work with triples
          # SalsaTigerSentence, FNTabSentence,
          # hash: tab sentence index(integer) -> array:SynNode
          parsed_file_obj.each_sentence do |st_sent, tabformat_sent, mapping|
            # parsed? then integrate semantics and lemmas from old file
            if @exp.get("do_parse")
              oldsent_string = oldxml[index]
              index += 1
              if oldsent_string
                oldsent_string = escape_berkeley_chars(oldsent_string)
                # we have both an old and a new sentence, so integrate semantics
                oldsent = STXML::SalsaTigerSentence.new(oldsent_string)

                next if st_sent.nil?

                unless FrappeHelper.integrate_stxml_semantics_and_lemmas(oldsent, st_sent, interpreter_class, @exp)
                  oldsent_string = oldxml[index]
                  index += 1
                  if oldsent_string
                    oldsent_string = escape_berkeley_chars(oldsent_string)
                    # we have both an old and a new sentence, so integrate semantics
                    oldsent = STXML::SalsaTigerSentence.new(oldsent_string)

                    FrappeHelper.integrate_stxml_semantics_and_lemmas(oldsent, st_sent, interpreter_class, @exp)
                  end
                end
              else
                # no corresponding old sentence for this new sentence
                @logger.warn "Warning: Transporting semantics - missing source sentence, skipping"
              end
            end
            # remove pseudo-frames from FrameNet data
            FrappeHelper.remove_deprecated_frames(st_sent, @exp)
            # repair syn/sem mapping problems?
            if @exp.get("fe_syn_repair") || @exp.get("fe_rel_repair")
              FixSynSemMapping.fixit(st_sent, @exp, interpreter_class)
            end

            outfile.puts st_sent.get
          end # each ST sentence
          outfile.puts STXML::SalsaTigerXMLHelper.get_footer
        end # each file parsed
      end

      ####
      # transform SalsaTigerXML file to Tab format file
      # @param [String] input_filename Name of input file.
      # @param [String] output_filename Name of output file.
      # @param [FrappeConfigData]
      def stxml_to_tab_file(input_filename, output_filename)
        corpus = STXML::Corpus.new(input_filename)

        File.open(output_filename, 'w') do |f|
          corpus.each_sentence do |sentence|
            raise 'Interface changed!!!' unless sentence.is_a?(Nokogiri::XML::Element)
            id = sentence.attributes['id'].value
            words = sentence.xpath('.//t')
            # byebug
            words.each do |word|
              word = STXML::SalsaTigerXMLHelper.unescape(word.attributes['word'].value)
              # @todo AB: I don't know why the Berkeley Parser wants this.
              #   Investigate if every Grammar needs this conversion.
              #   Try to move this convertion from FrappeHelper to BerkeleyInterface.
              if @exp.get("parser") == "berkeley"
                word.gsub!(/\(/, "*LRB*")
                word.gsub!(/\)/, "*RRB*")
                word.gsub!(/``/, '"')
                word.gsub!(/''/, '"')
                word.gsub!(%r{\&apos;\&apos;}, '"')
              end
              fields = {'word' => word, 'sent_id' => id}
              f.puts FNTabFormatFile.format_str(fields)
            end
            f.puts
          end
        end
      end
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
        dirname = File.new_dir(@exp.get("frprep_directory"), @exp.get("prep_experiment_ID"), subdir)

        neu ? File.new_dir(dirname) : File.existing_dir(dirname)
      end


      def escape_berkeley_chars(str)
        # modified by ines, 27/08/08
        # for Berkeley => substitute ( ) for *LRB* *RRB*
        # @note AB: Duplicated code!! Move it to the Berkeley Interface.
        if @exp.get("parser") == "berkeley"
          str.gsub!(/word='\('/, "word='*LRB*'")
          str.gsub!(/word='\)'/, "word='*RRB*'")
          str.gsub!(/word=\"\(\"/, "word='*LRB*'")
          str.gsub!(/word=\"\)\"/, "word='*RRB*'")
        end

        str
      end
    end
  end
end
