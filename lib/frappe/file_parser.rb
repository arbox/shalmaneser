# -*- encoding: utf-8 -*-

require_relative 'one_parsed_file'
require_relative 'frappe_read_stxml'
require_relative 'frappe_flat_syntax'
require 'external_systems'
require 'logger'

module Shalmaneser
  module Frappe
    ##############################
    # class for managing parses:
    #
    # Given either a directory with tab format files or
    # a directory with SalsaTigerXML files (or both) and
    # a directory for putting parse files:
    # - parse, unless no parsing set in the experiment file
    # - for each parsed file: yield one OneParsedFile object
    class FileParser
      # @param [FrappeConfigData] exp
      # @param [Hash<String, String>] file_suffixes Hash: file type(string) -> suffix(string)
      # @param [String] parse_dir string: name of directory to put parses
      # @param [Hash] dirs further directories
      def initialize(exp, file_suffixes, parse_dir, dirs = {})
        @exp = exp
        @file_suffixes = file_suffixes
        @parse_dir = parse_dir
        @tab_dir = dirs["tab_dir"]
        @stxml_dir = dirs["stxml_dir"]
        # pre-parsed data available?
        @parsed_files = @exp.get("directory_parserout")
      end

      ###
      def each_parsed_file
        postag_suffix = @exp.get("do_postag") ? @file_suffixes["pos"] : nil

        lemma_suffix = @exp.get("do_lemmatize") ? @file_suffixes["lemma"] : nil

        if @exp.get("do_parse")
          # get parser interface
          sys_class = ExternalSystems.get_interface("parser", @exp.get("parser"))

          # This suffix is used as extension for parsed files.
          parse_suffix = ".#{sys_class.name.split('::').last}"

          sys = sys_class.new(@exp.get("parser_path"),
                              @file_suffixes["tab"],
                              parse_suffix,
                              @file_suffixes["stxml"],
                              "pos_suffix" => postag_suffix,
                              "lemma_suffix" => lemma_suffix,
                              "tab_dir" => @tab_dir)

          if @parsed_files
            # reuse old parses
            LOGGER.info "#{PROGRAM_NAME}: Using pre-computed parses in #{@parsed_files}.\n"\
                        "#{PROGRAM_NAME} Postprocessing SalsaTigerXML data."

            Dir[@parsed_files + "*"].each do |parsefilename|
              if File.stat(parsefilename).ftype != "file"
                # something other than a file
                next
              end
              # core filename: remove directory and anything after the last "."
              filename_core = File.basename(parsefilename, ".*")

              # use iterator to read each parsed file
              yield OneParsedFile.new(filename_core, parsefilename, sys)
            end
          else
            # do new parses
            LOGGER.info "#{PROGRAM_NAME}: Syntactic analysis with #{sys.class.name.split('::').last}."

            unless @tab_dir
              raise "Cannot parse without tab files"
            end

            # @note AB: NOTE This is the position where a parser is invoked.
            # parse
            sys.process_dir(@tab_dir, @parse_dir)

            LOGGER.info "#{PROGRAM_NAME}: Postprocessing SalsaTigerXML data."

            Dir[@parse_dir + "*" + parse_suffix].each do |parsefilename|
              filename_core = File.basename(parsefilename, parse_suffix)

              # use iterator to read each parsed file
              yield OneParsedFile.new(filename_core, parsefilename, sys)
            end
          end
        else
          # no parse:
          # get pseudo-parse tree
          if @stxml_dir
            # use existing SalsaTigerXML files
            Dir[@stxml_dir + "*.xml"].each do |stxmlfilename|
              filename_core = File.basename(stxmlfilename, ".xml")
              if @tab_dir
                # we know the tab directory too
                tabfilename = @tab_dir + filename_core + @file_suffixes["tab"]
                each_sentence_obj = FrappeReadStxml.new(stxmlfilename, tabfilename,
                                                        postag_suffix, lemma_suffix)
              else
                # we have no tab directory
                each_sentence_obj = FrappeReadStxml.new(stxmlfilename, nil,
                                                        postag_suffix, lemma_suffix)
              end

              yield OneParsedFile.new(filename_core, stxmlfilename, each_sentence_obj)
            end
          else
            # construct SalsaTigerXML from tab files
            Dir[@tab_dir + "*" + @file_suffixes["tab"]].each do |tabfilename|
              each_sentence_obj = FrappeFlatSyntax.new(tabfilename,
                                                       postag_suffix,
                                                       lemma_suffix)
              filename_core = File.basename(tabfilename, @file_suffixes["tab"])
              yield OneParsedFile.new(filename_core, tabfilename, each_sentence_obj)
            end
          end # source of pseudo-parse
        end # parse or no parse
      end
    end
  end
end
