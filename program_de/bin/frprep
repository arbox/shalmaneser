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
require 'frprep'
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

