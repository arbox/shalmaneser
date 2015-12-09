# -*- encoding: utf-8 -*-

# AB, 2010-11-25

require 'optparse'
require 'common/prep_config_data'
require 'common/SynInterfaces'

module FrPrep
  # This class parses options for FrPrep.
  class OptParser
    # Main class method.
    # OP expects cmd_args to be an array like ARGV.
    def self.parse(cmd_args)
      @prg_name = 'frprep'
      @options = {}
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

      exp = FrPrepConfigData.new(@options[:exp_file])

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
        opts.banner = <<STOP
Fred Preprocessor <FrPrep>. Preprocessing stage before Fred and Rosy
for further frame/word sense assignment and semantic role assignment.

Usage: frprep -h|-e FILENAME'
STOP
        opts.separator ''
        opts.separator 'Program specific options:'

        opts.on('-e', '--expfile FILENAME',
                'Provide the path to an experiment file.',
                'FrPrep will preprocess data according to the specifications',
                'given in your experiment file.',
                'This option is required!',
                'Also consider the documentation on format and features.'
                ) do |exp_file|
          @options[:exp_file] = File.expand_path(exp_file)
        end

        opts.separator ''
        opts.separator 'Common options:'

        opts.on_tail('-h', '--help', 'Show this help message.') do
          puts opts
          exit
        end
      end
    end # def self.parse
  end # class OptParser
end # module FrPrep
