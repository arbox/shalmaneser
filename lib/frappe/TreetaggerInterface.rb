# sp 30 11 06
# extended by TreeTaggerPOSInterface

require "tempfile"
require 'pathname'
require "common/AbstractSynInterface"

###########
# KE dec 7, 06
# common mixin for both Treetagger modules, doing the actual processing
module TreetaggerModule
  ###
  # Treetagger does both lemmatization and POS-tagging.
  # However, the way the SynInterface system is set up in Shalmaneser,
  # each SynInterface can offer only _one_ service.
  # This means that we cannot do a SynInterface that writes
  # both a POS file and a lemma file.
  # Instead, both will include this module, which does the
  # actual TreeTagger call and then stores the result in a file
  # of its own, similar to the 'outfilename' given to TreetaggerInterface.process_file
  # but with a separate extension.
  # really_process_file checks for existence of this file because,
  # if the TreeTagger lemmatization and POS-tagging classes are called separately,
  # one of them will go first, and the 2nd one will not need to do the
  # TreeTagger call anymore
  #
  # really_process_file returns a filename, the name of the file containing
  # the TreeTagger output with both POS tags and lemma information
  #
  # WARNING: this method assumes that outfilename contains a suffix
  # that can be replaced by .TreeTagger
  def really_process_file(infilename, # string: name of input file
                          outfilename, # string: name of file that the caller is to produce
                          make_new_outfile_anyway = false) # Boolean: run TreeTagger in any case?

    # fabricate the filename in which the
    # actual TreeTagger output will be placed:
    # <directory> + <outfilename minus last suffix> + ".TreeTagger"
    current_suffix = outfilename[outfilename.rindex(".")..-1]
    my_outfilename = File.dirname(outfilename) + "/" +
                     File.basename(outfilename, current_suffix) +
                     ".TreeTagger"

    ##
    # does it exist? then just return it
    if !make_new_outfile_anyway && File.exist?(my_outfilename)
      my_outfilename
    end

    ##
    # else construct it, then return it
    tempfile = Tempfile.new("Treetagger")
    TreetaggerInterface.fntab_words_to_file(infilename, tempfile, "<EOS>", "iso")
    tempfile.close

    # @todo AB: Remove it by my shame :(
    # AB: A very dirty hack of mine:
    # We need the language attribute, but we don't have the FrPrepConfigData,
    # then we'll try to find it in the ObjectSpace since we should have only one.
    lang = ''
    ObjectSpace.each_object(Shalmaneser::Configuration::FrPrepConfigData) do |o|
      lang = o.get('language')
    end

    case lang
    when 'en'
      tt_model = Pathname.new(@program_path).join('lib').join(ENV['SHALM_TREETAGGER_MODEL'] || 'english.par')
      tt_filter = ''
    when 'de'
      tt_model = Pathname.new(@program_path).join('lib').join(ENV['SHALM_TREETAGGER_MODEL'] || 'german.par')
      tt_filter = "#{Pathname.new(@program_path).join('cmd').join('filter-german-tags')}"
    end

    # call TreeTagger
    tt_binary = Pathname.new(@program_path).join('bin').join(ENV.fetch('SHALM_TREETAGGER_BIN', 'tree-tagger'))

    invocation_str = "#{tt_binary} -lemma -token -sgml #{tt_model} "\
                     "#{tempfile.path} 2>/dev/null | #{tt_filter} > #{my_outfilename}"

    STDERR.puts "*** Tagging and lemmatizing #{tempfile.path} with TreeTagger."
    STDERR.puts invocation_str

    Kernel.system(invocation_str)
    tempfile.close(true) # delete first tempfile

    # external problem: sometimes, the treetagger keeps the last <EOS> for itself,
    # resulting on a .tagged file missing the last (blank) line

    original_length = File.readlines(infilename).size
    lemmatised_length = File.readlines(infilename).size

    case (original_length - lemmatised_length)
    when 0
      # everything ok, don't do anything
    when 1
      # @todo Add here a Logger Warning.
      # add one more newline to the .tagged file
      `echo "" >> #{my_outfilename}`
    else
      # this is "real" error
      STDERR.puts "Original length: #{original_length}\tLemmatised length: #{lemmatised_length}"
      STDERR.puts "Error: lemmatiser/tagger output for for #{File.basename(infilename)}"
      $stderr.puts "has different line number from corpus file!"
      raise
    end

    my_outfilename
  end
end

#######################################
class TreetaggerInterface < SynInterfaceTab
  TreetaggerInterface.announce_me

  include TreetaggerModule

  ###
  def self.system
    'treetagger'
  end

  ###
  def self.service
    'lemmatizer'
  end

  ###
  # convert TreeTagger's penn tagset into Collins' penn tagset *argh*
  # @todo AB: Generalize this method to work with different parsers.
  def convert_to_berkeley(line)
    line.chomp.gsub(/\(/, "-LRB-").gsub(/\)/, "-RRB-").gsub(/''/, "\"").gsub(/\`\`/, "\"")
  end

  ###
  # @param [String] infilename The name of the input file.
  # @param [String] outfilename The name of the output file.
  def process_file(infilename, outfilename)
    ttfilename = really_process_file(infilename, outfilename)

    # write all output to tempfile2 first, then
    # change ISO to UTF-8 into outputfile
    tempfile2 = Tempfile.new("treetagger")
    tempfile2.close

    # 2. use cut to get the actual lemmtisation

    Kernel.system("cat " + ttfilename +
                  ' | sed -e\'s/<EOS>//\' | cut -f3 > ' + tempfile2.path)

    # transform ISO-8859-1 back to UTF-8,
    # write to 'outfilename'
    begin
      outfile = File.new(outfilename, "w")
    rescue
      raise "Could not write to #{outfilename}"
    end
    tempfile2.open

    # AB: Internally all the flow is an utf-8 encoded stream.
    # TreeTagger consumes one byte encodings (but we should provide a
    # utf-8 model for German). So we convert utf-8 to latin1, then
    # process the text and convert it back to utf-8.
    #
    while (line = tempfile2.gets)
      utf8line = UtfIso.from_iso_8859_1(line)
      outfile.puts convert_to_berkeley(utf8line)
    end

    # remove second tempfile, finalize output file
    tempfile2.close(true)
    outfile.close
  end
end

# sp 30 11 06
#
# using TreeTagger for POS tagging of English text
#
# copy-and-paste from lemmatisation
#
# differences:
# 1. use field 2 and not 3 from the output
# 2. convert tags from what Treetagger thinks is the Penn Tagset to what TnT and Collins think is the Penn Tagset
#
# KE 7 12 06
# change interface such that TreeTagger is called only once
# and both POS tags and lemma are read from the same files,
# rather than calling the tagger twice
class TreetaggerPOSInterface < SynInterfaceTab
  include TreetaggerModule

  TreetaggerPOSInterface.announce_me

  ###
  def self.system
    "treetagger"
  end

  ###
  def self.service
    "pos_tagger"
  end

  ###
  # convert TreeTagger's penn tagset into Collins' penn tagset *argh*
  def convert_to_collins(line)
    line.chomp.gsub(/^PP/, "PRP").gsub(/^NP/, "NNP").gsub(/^VV/, "VB").gsub(/^VH/, "VB").gsub(/^SENT/, ".")
  end

  ###
  # @param [String] infilename Name of input file.
  # @param [String] outfilename Name of output file.
  def process_file(infilename, outfilename)
    # KE change here
    tt_filename = really_process_file(infilename, outfilename, true)

    # write all output to tempfile2 first, then
    # change ISO to UTF-8 into outputfile
    tempfile2 = Tempfile.new("treetagger")
    tempfile2.close

    # 2. use cut to get the actual lemmtisation

    Kernel.system("cat " + tt_filename +
                  ' | sed -e\'s/<EOS>//\' | cut -f2 > ' + tempfile2.path)

    # transform ISO-8859-1 back to UTF-8,
    # write to 'outfilename'
    begin
      outfile = File.new(outfilename, "w")
    rescue
      raise "Could not write to #{outfilename}"
    end
    tempfile2.open
    while (line = tempfile2.gets)
      outfile.puts UtfIso.from_iso_8859_1(convert_to_collins(line))
    end

    # remove second tempfile, finalize output file
    tempfile2.close(true)
    outfile.close
  end
end

###############
# an interpreter that only has Treetagger, no parser
class TreetaggerInterpreter < SynInterpreter
  TreetaggerInterpreter.announce_me

  ###
  # names of the systems interpreted by this class:
  # returns a hash service(string) -> system name (string),
  # e.g.
  # { "parser" => "collins", "lemmatizer" => "treetagger" }
  def self.systems
    {"pos_tagger" => "treetagger"}
  end

  ###
  # names of additional systems that may be interpreted by this class
  # returns a hash service(string) -> system name(string)
  # same as names()
  def self.optional_systems
    {"lemmatizer" => "treetagger"}
  end

  ###
  # generalize over POS tags.
  #
  # returns one of:
  #
  # adj:  adjective (phrase)
  # adv:  adverb (phrase)
  # card: numbers, quantity phrases
  # con:  conjunction
  # det:  determiner, including possessive/demonstrative pronouns etc.
  # for:  foreign material
  # noun: noun (phrase), including personal pronouns, proper names, expletives
  # part: particles, truncated words (German compound parts)
  # prep: preposition (phrase)
  # pun:  punctuation, brackets, etc.
  # sent: sentence
  # top:  top node of a sentence
  # verb: verb (phrase)
  # nil:  something went wrong
  #
  # returns: string, or nil
  def self.category(node) # SynNode
    pt = TreetaggerInterpreter.pt(node)
    # phrase type could not be determined
    return nil if pt.nil?

    case pt.to_s.strip.match(/^([^-]*)/)[1]
    when /^JJ/, /(WH)?ADJP/, /^PDT/
      "adj"
    when /^RB/, /(WH)?ADVP/, /^UH/
      "adv"
    when /^CD/, /^QP/
      "card"
    when /^CC/, /^WRB/, /^CONJP/
      "con"
    when /^DT/, /^POS/
      "det"
    when /^FW/, /^SYM/
      "for"
    when /^N/, "WHAD", "WDT", /^PRP/, /^WHNP/, /^EX/, /^WP/
      "noun"
    when /^IN/, /^TO/, /(WH)?PP/, "RP", /^PR(T|N)/
      "prep"
    when /^PUNC/, /LRB/, /RRB/, /[,'".:;!?\(\)]/
      "pun"
    when /^S(s|bar|BAR|G|Q|BARQ|INV)?$/, /^UCP/, /^FRAG/, /^X/, /^INTJ/
      "sent"
    when /^TOP/
      "top"
    when /^TRACE/
      "trace"
    when /^V/, /^MD/
      "verb"
    else
      # @todo Change this to a Logger warning.
      STDERR.puts "WARNING: Unknown category/POS " + pt.to_s + " (English data)."
      nil
    end
  end
end
