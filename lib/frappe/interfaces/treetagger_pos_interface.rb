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

require 'tempfile'
require 'common/ISO-8859-1'
require_relative 'treetagger_module'

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
