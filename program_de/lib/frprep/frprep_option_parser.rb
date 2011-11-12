# -*- encoding: us-ascii -*-

# AB, 2010-11-25

require 'option_parser'

# This class parses the option for FRPrep.
class FRPrepOptionParser < OptionParser


  def usage
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
end
