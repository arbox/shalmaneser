require 'logging'
module Shalmaneser
  module Frappe
    class SalsaTabWithPOSConverter
      def initialize(exp)
        @exp = exp
        # suffixes for different types of output files
        @file_suffixes = {"lemma" => ".lemma", "pos" => ".pos", "tab" => ".tab", "stxml" => ".xml"}
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
        interpreter_class = ExternalSystems.get_interpreter_according_to_exp(@exp)

        unless interpreter_class
          raise "Shouldn't be here"
        end

        parse_obj = FileParser.new(@exp, @file_suffixes, parse_dir, "tab_dir" => input_dir)

        parse_obj.each_parsed_file do |parsed_file_obj|
          outfilename = output_dir + parsed_file_obj.filename + ".xml"
          LOGGER.debug "Writing #{outfilename}."

          begin
            outfile = File.new(outfilename, "w")
          rescue
            raise "Cannot write to SalsaTigerXML output file #{outfilename}"
          end

          outfile.puts STXML::SalsaTigerXMLHelper.get_header
          # work with triples
          # SalsaTigerSentence, FNTabSentence,
          # hash: tab sentence index(integer) -> array:SynNode
          parsed_file_obj.each_sentence do |st_sent, tabformat_sent, mapping|
            # parsed: add headwords using parse tree
            if @exp.get("do_parse")
              FrappeHelper.add_head_attributes(st_sent, interpreter_class)
            end

            # add lemmas, if they are there. If they are not, don't print out a warning.
            if @exp.get("do_lemmatize")
              FrappeHelper.add_lemmas_from_tab(st_sent, tabformat_sent, mapping)
            end

            # add semantics
            # we can use the method in SalsaTigerXMLHelper
            # that reads semantic information from the tab file
            # and combines all targets of a sentence into one frame
            FrappeHelper.add_semantics_from_tab(st_sent, tabformat_sent, mapping, interpreter_class, @exp)

            # remove pseudo-frames from FrameNet data
            FrappeHelper.remove_deprecated_frames(st_sent, @exp)

            # handle multiword targets
            FrappeHelper.handle_multiword_targets(st_sent, interpreter_class, @exp.get("language"))

            # handle Unknown frame names
            FrappeHelper.handle_unknown_framenames(st_sent, interpreter_class)

            outfile.puts st_sent.get
          end
          outfile.puts STXML::SalsaTigerXMLHelper.get_footer
        end
      end
    end
  end
end
