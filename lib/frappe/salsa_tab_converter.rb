module Shalmaneser
  module Frappe
    class SalsaTabConverter
      def initialize(exp)
        @exp = exp
        # suffixes for different types of output files
        @file_suffixes = {"lemma" => ".lemma", "pos" => ".pos", "tab" => ".tab", "stxml" => ".xml"}
      end

           ###############
      # transform_pos_and_lemmatize
      #
      # transformation for Tab format files:
      #
      # - Split into parser-size chunks
      # - POS-tag, lemmatize
      # string: input directory
      # string: output directory
      def transform_pos_and_lemmatize(input_dir, output_dir)
        ##
        # split the TabFormatFile into chunks of max_sent_num size
        FrappeHelper.split_dir(input_dir, output_dir, @file_suffixes["tab"],
                               @exp.get("parser_max_sent_num"),
                               @exp.get("parser_max_sent_len"))

        ##
        # POS-Tagging
        if @exp.get("do_postag")
          LOGGER.info "#{PROGRAM_NAME}: Tagging."

          sys_class = ExternalSystems.get_interface("pos_tagger", @exp.get("pos_tagger"))

          # AB: TODO Remove it.
          unless sys_class
            raise "Shouldn't be here"
          end

          LOGGER.debug "POS Tagger interface: #{sys_class}."
          sys = sys_class.new(@exp.get("pos_tagger_path"), @file_suffixes["tab"], @file_suffixes["pos"])
          sys.process_dir(output_dir, output_dir)
        end

        ##
        # Lemmatization
        # AB: We're working on the <split> dir and writing there.
        if @exp.get("do_lemmatize")
          LOGGER.info "#{PROGRAM_NAME}: Lemmatizing."

          sys_class = ExternalSystems.get_interface("lemmatizer", @exp.get("lemmatizer"))
          # AB: TODO make this exception explicit.
          unless sys_class
            raise 'I got a empty interface class for the lemmatizer!'
          end

          sys = sys_class.new(@exp.get("lemmatizer_path"), @file_suffixes["tab"], @file_suffixes["lemma"])
          sys.process_dir(output_dir, output_dir)
        end
      end


    end
  end
end
