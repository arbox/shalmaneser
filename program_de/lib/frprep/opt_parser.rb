
# -*- encoding: us-ascii -*-

# AB, 2010-11-25

require 'optparse'
require 'common/FrPrepConfigData'
require 'common/SynInterfaces'
module FrPrep

  # This class parses the option for FRPrep.
  class OptParser

    # Main class method.
    # OP expects cmd_args to be an array like ARGV.
    def self.parse(cmd_args)
      @prg_name = 'frprep'
      @@options = {}
      
      parser = create_parser
      
      # If no options provided print the help.
      if cmd_args.empty?
        $stderr.puts('You have to provide some options.',
                    "Please start with <#{@prg_name} --help>.")
        exit(1)
      end
      
      # Parse ARGV and provide the options hash.
      # Check if everything is correct and handle exceptions
      begin
        parser.parse(cmd_args)
      rescue OptionParser::InvalidArgument => e
        arg = e.message.split.last
        $stderr.puts "The provided argument #{arg} is currently not supported!"
        $stderr.puts "Please colsult <#{@prg_name} --help>."
        exit(1)
      rescue OptionParser::InvalidOption => e
        $stderr.puts "You have provided an #{e.message}."
        $stderr.puts "Please colsult <#{@prg_name} --help>."
        exit(1)
      rescue
        raise
      end

      
      exp = FrPrepConfigData.new(@@options[:exp_file])

      # AB: this stuff should be move into FrPrepConfigData.
      # sanity checks
      unless exp.get("prep_experiment_ID") =~ /^[A-Za-z0-9_]+$/
        raise "Please choose an experiment ID consisting only of the letters A-Za-z0-9_."
      end

      SynInterfaces.check_interfaces_abort_if_missing(exp)

      exp
    end

    private
    def self.create_parser
      OptionParser.new do |opts|
        opts.banner = 'Usage: frprep OPTIONS'
        
        opts.separator ''
        opts.separator 'Program specific options:'
        
        opts.on('-e', '--expfile FILENAME',
                'Provide the path to an experiment file,',
                'to test Yanser you can use <YahooDemo> as the APPID,',
                'think in this case on limitations placed by Yahoo.',
                'This option is required!'
                ) do |exp_file|
          @@options[:exp_file] = File.expand_path(exp_file)
        end

        opts.separator ''
        opts.separator 'Common options:'
        
        opts.on_tail('-h', '--help', 'Show the help message.') do
          puts opts
          exit
        end
        
      end
    end

    def usage
      $stderr.puts "
FrPrep: Preprocessing for Fred and Rosy
(i.e. for frame/word sense assignment and semantic role assignment)
  
Usage:
----------------




ruby frprep.rb --expfile|-e <e>
  Preprocess data according to the specifications
  of experiment file <e>.

  <e>: path to experiment file

  For specifics on the contents of the experiment file,
  see the file SAMPLE_EXPERIMENT_FILE in this directory.

"
    end
  end
end
