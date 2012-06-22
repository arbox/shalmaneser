require "tempfile"
require "frprep/AbstractSynInterface"

################################################
# Interface class
class TntInterface < SynInterfaceTab
  TntInterface.announce_me()

  def TntInterface.system()
    return "tnt"
  end

  def TntInterface.service()
    return "pos_tagger"
  end

  def process_file(infilename,   # string: name of input file
		   outfilename)  # string: name of output file

    tempfile = Tempfile.new("Tnt")
    TntInterface.fntab_words_to_file(infilename, tempfile)
    tempfile.close

    # 1. use grep to remove commentaries from file      
    # 2. use sed to extract tags tag list:
    #    - match one or more non-spaces
    #    - match one or more spaces
    #    - match one or more non-spaces and write to outfilename 
    
    # This assumes that the experiment file entry for pos_tagger_path
    # has the form 
    # pos_tagger_path = <program_name> <model>

    Kernel.system(@program_path + " " + tempfile.path +
		  ' | grep -v -E "^%%" |  sed -e\'s/^[^ ]\{1,\}[[:space:]]\{1,\}\([^ ]\{1,\}\)/\1/\' > '+outfilename)

    tempfile.close(true) # delete tempfile
    unless `cat #{infilename} | wc -l`.strip ==
                                     `cat #{outfilename} | wc -l`.strip
      raise "Error: tagged file has different line number from corpus file!"
    end   
  end
end

