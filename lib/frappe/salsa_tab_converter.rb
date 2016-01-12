require 'logging'
require 'external_systems'

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
        split_dir(input_dir, output_dir, @file_suffixes["tab"], @exp.get("parser_max_sent_num"), @exp.get("parser_max_sent_len"))

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


      ###########
      #
      # class method split_dir:
      # read all files in one directory and produce chunk files with _suffix_ in outdir
      # with a certain number of files in them (sent_num).
      # Optionally, remove all sentences longer than sent_leng
      #
      # produces output files 1.<suffix>, 2.<suffix>, etc.
      #
      # assumes TabFormat sentences
      #
      # example: split_all("/tmp/in","/tmp/out",".tab",2000,80)
      def split_dir(indir, outdir, suffix, sent_num, sent_leng = nil)
        unless indir[-1,1] == "/"
          indir += "/"
        end
        unless outdir[-1,1] == "/"
          outdir += "/"
        end

        # @note AB: A dummy reimplementation.
        #   Not doing splitting at all.
        #   I want to preserve original file names.
        Dir["#{indir}*#{suffix}"].each do |file|
          FileUtils.cp file, outdir
        end
        # @note AB: Not doing splitting for now.
=begin
        outfile_counter = 0
        line_stack = []
        sent_stack = []

        Dir[indir + "*#{suffix}"].each do |infilename|
          LOGGER.info "Now splitting #{infilename}."

          infile = File.new(infilename)

          while (line = infile.gets)
            line.chomp!
            case line
            when "" # end of sentence
              if !(sent_leng.nil? or line_stack.length < sent_leng) # record sentence
                # suppress multiple empty lines
                # to avoid problems with lemmatiser
                # only record sent_stack if it is not empty.

                # change (sp 15 01 07): just cut off sentence at sent_leng.

                STDERR.puts "Cutting off long sentence #{line_stack.last.split("\t").last}"
                line_stack = line_stack[0...sent_leng]
              end

              unless line_stack.empty?
                sent_stack << line_stack
                # reset line_stack
                line_stack = []
              end

              # check if we have to empty the sent stack
              if sent_stack.length == sent_num # enough sentences for new outfile?
                outfile = File.new(outdir + outfile_counter.to_s + "#{suffix}", "w")

                sent_stack.each { |l_stack|
                  outfile.puts l_stack.join("\n")
                  outfile.puts
                }

                outfile.close
                outfile_counter += 1
                sent_stack = []
              end
            else # for any other line
              line_stack << line
            end
          end
          infile.close
        end

        # the last remaining sentences
        unless sent_stack.empty?
          File.open(outdir + outfile_counter.to_s + "#{suffix}", "w") do |outfile|
            sent_stack.each { |l_stack|
              l_stack << "\n"
              outfile.puts l_stack.join("\n")
            }
          end
        end
=end
      end

    end
  end
end
