require 'frappe/utf_iso'

# For FN input.
require 'framenet_format/fn_corpus_xml_file' # !
require 'framenet_format/fn_database' # !

require 'logging' # !

require 'frappe/stxml_converter'
require 'frappe/plain_converter'
require 'frappe/salsa_tab_converter'
require 'frappe/salsa_tab_with_pos_converter'

##############################
# The class that does all the work
module Shalmaneser
  module Frappe
    class Frappe
      # @param exp [FrappeConfigData] Configuration object
      def initialize(exp)
        @exp = exp
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

          LOGGER.info "Frappe: Transforming  to UTF-8."

          Dir[input_dir + "*"].each do |filename|
            unless File.file? filename
              # not a file? then skip
              next
            end
            outfilename = encoding_dir + File.basename(filename)
            to_utf8_file(filename, outfilename, @exp.get("encoding"))
          end

          input_dir = encoding_dir
        end

        ####
        # transform data all the way to the output format,]
        # which is SalsaTigerXML by default,
        # except when tabformat_output has been set, in which case it's
        # Tab format.
        current_dir = input_dir

        current_format = @exp.get("format")

        # while current_format != done_format
        # @todo Change the configuration to input_format vs. output_format.
        #   Input Formats:
        #   Output Formats: STXML (default), TABULAR
        loop do
          case current_format
          when "Plain"
            tab_dir = frprep_dirname("tab", "new")

            LOGGER.info "Frappe: Transforming plain text to SalsaTab format."
            LOGGER.debug "Frappe: Transforming plain text in #{current_dir} to SalsaTab format.\n"\
                          "Storing the result in #{tab_dir}.\n"\
                          "Expecting one sentence per line.\n"

            transformer = PlainConverter.new
            transformer.transform_plain_dir(current_dir, tab_dir)

            current_dir = tab_dir
            current_format = "SalsaTab"

          when "FNXml"
            # transform to tab format

            tab_dir = frprep_dirname("tab", "new")

            LOGGER.info 'Frappe: Transforming FN Data to the tabular format.'
            LOGGER.debug "Frappe: Transforming FN data in #{current_dir} to the "\
                          "tabular format. Storing the result in #{tab_dir}"

            fndata = FNDatabase.new(current_dir)
            fndata.extract_everything(tab_dir)

            current_dir = tab_dir
            current_format = "SalsaTab"

          when "FNCorpusXml"
            # transform to tab format
            tab_dir = frprep_dirname("tab", "new")

            LOGGER.info 'Frappe: Transforming FrameNet data to the tabular format.'
            LOGGER.debug "Frprep: Transforming FN data in #{current_dir} to tabular format.\n"\
                          "Storing the result in: #{tab_dir}.\n"

            # assuming that all XML files in the current directory are FN Corpus XML files
            Dir[current_dir + "*.xml"].each do |fncorpusfilename|
              corpus = FNCorpusXMLFile.new(fncorpusfilename)
              output_file = "#{tab_dir}#{File.basename(fncorpusfilename, '.xml')}.tab"
              File.open(output_file, 'w') do |f|
                corpus.print_conll_style(f)
              end
            end

            current_dir = tab_dir
            current_format = "SalsaTab"

          when "SalsaTab"
            LOGGER.info "#{PROGRAM_NAME}: I'm Lemmatizing and Parsing texts."
            LOGGER.debug "#{PROGRAM_NAME}: Lemmatizing and parsing text in #{current_dir}.\n"\
                          "Storing the result in #{split_dir}.\n"

            transformer = SalsaTabConverter.new(@exp)
            transformer.transform_pos_and_lemmatize(current_dir, split_dir)

            # current_format = "SalsaTabWithPos"
            if @exp.get("tabformat_output")
              break
            else
              current_format = 'SalsaTabWithPos'
              current_dir = split_dir
            end

          when "SalsaTabWithPos"
            parse_dir = frprep_dirname("parse", "new")

            LOGGER.info 'Frappe: Trasforming the tabular format into the STXML format.'
            LOGGER.debug "Frprep: Transforming tabular format text in #{current_dir} to SalsaTigerXML format. "\
                          "Storing the result in #{parse_dir}."

            transformer = SalsaTabWithPOSConverter.new(@exp)
            transformer.transform_salsatab_dir(current_dir, parse_dir, output_dir)
            break
          when "SalsaTigerXML"
            parse_dir = frprep_dirname("parse", "new")
            LOGGER.info "#{PROGRAM_NAME}: Transforming parser output into STXML format."
            transformer = STXMLConverter.new(@exp)
            transformer.transform_stxml_dir(parse_dir, split_dir, input_dir, output_dir)
            break
          end
        end

        LOGGER.info "#{PROGRAM_NAME} is ready! Preprocessing of all the texts is finished."
      end

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
        dirname = File.new_dir(@exp.get("frprep_directory"), @exp.get("prep_experiment_ID"), subdir)

        neu ? File.new_dir(dirname) : File.existing_dir(dirname)
      end
      ####
      # transform a file to UTF-8 from a given encoding
      # @note Is used.
      def to_utf8_file(input_filename, # string: name of input file
                                    output_filename, # string: name of output file
                                    encoding) # string: "iso", "hex"
        begin
          infile = File.new(input_filename)
          outfile = File.new(output_filename, "w")
        rescue
          raise "Could not read #{input_filename}, or could not write to #{output_filename}."
        end

        while (line = infile.gets)
          case encoding
          when "iso"
            outfile.puts UtfIso.from_iso_8859_1(line)
          when "hex"
            outfile.puts UtfIso.from_iso_8859_1(Ampersand.hex_to_iso(line))
          else
            raise "Shouldn't be here."
          end
        end
        infile.close
        outfile.close
      end

    end
  end
end
