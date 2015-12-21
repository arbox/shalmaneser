# -*- encoding: utf-8 -*-

# AB, 2010-11-25

##############################
# class for managing parses:
#
# Given either a directory with tab format files or
# a directory with SalsaTigerXML files (or both) and
# a directory for putting parse files:
# - parse, unless no parsing set in the experiment file
# - for each parsed file: yield one OneParsedFile object
require_relative 'one_parsed_file'
require_relative 'frappe_read_stxml'
require_relative 'frappe_flat_syntax'
require 'syn_interfaces'

module Shalmaneser
  module Frappe
    class DoParses
      def initialize(exp,           # FrappeConfigData object
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
      def each_parsed_file
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
          parse_suffix = "." + sys_class.name
          sys = sys_class.new(@exp.get("parser_path"),
                              @file_suffixes["tab"],
                              parse_suffix,
                              @file_suffixes["stxml"],
                              "pos_suffix" => postag_suffix,
                              "lemma_suffix" => lemma_suffix,
                              "tab_dir" => @tab_dir)

          if @parsed_files
            # reuse old parses

            $stderr.puts "Frprep: using pre-computed parses in " + @parsed_files.to_s
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

            # AB: NOTE This is the position where a parser is invoked.
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
                each_sentence_obj = FrappeReadStxml.new(stxmlfilename, tabfilename,
                                                        postag_suffix, lemma_suffix)
              else
                # we have no tab directory
                each_sentence_obj = FrappeReadStxml.new(stxmlfilename, nil,
                                                        postag_suffix, lemma_suffix)
              end

              yield OneParsedFile.new(filename_core, stxmlfilename, each_sentence_obj)
            }

          else
            # construct SalsaTigerXML from tab files
            Dir[@tab_dir+"*"+@file_suffixes["tab"]].each { |tabfilename|
              each_sentence_obj = FrappeFlatSyntax.new(tabfilename,
                                                       postag_suffix,
                                                       lemma_suffix)
              filename_core = File.basename(tabfilename, @file_suffixes["tab"])
              yield OneParsedFile.new(filename_core, tabfilename, each_sentence_obj)
            }
          end # source of pseudo-parse
        end # parse or no parse
      end
    end
  end
end
