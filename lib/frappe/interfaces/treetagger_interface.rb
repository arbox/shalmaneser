require_relative 'treetagger_module'
require 'frappe/syn_interface_tab'
require 'common/ISO-8859-1'
require 'tempfile'

class TreetaggerInterface < SynInterfaceTab
  include TreetaggerModule

  TreetaggerInterface.announce_me

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
