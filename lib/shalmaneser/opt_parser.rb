require 'optparse'
require 'shalmaneser/version'


module Shalmaneser
  class OptParser
    def self.parse(cmd_args)

      parser = create_parser

      if cmd_args.empty?
        cmd_args << '-h'
      end

      # Parse ARGV and provide the options hash.
      # Check if everything is correct and handle exceptions
      begin
        parser.parse(cmd_args)
      rescue OptionParser::InvalidArgument => e
        arg = e.message.split.last
        puts "The provided argument #{arg} is currently not supported by Shalmaneser!"
        puts 'Please colsult <shalmaneser --help>.'
        exit(1)
      rescue OptionParser::InvalidOption => e
        puts "You have provided an #{e.message}."
        puts 'Please colsult <shalmaneser --help>.'
        exit(1)
      rescue
        raise
      end
    end

    def self.create_parser
      OptionParser.new do |opts|
        opts.banner = 'Usage: shalmaneser OPTIONS'
        opts.separator ''
        opts.separator 'Common options:'
        
        opts.on_tail('-h', '--help', 'Show the help message.') do
          puts opts
          exit
        end
        
        opts.on_tail('-v', '--version', 'Show the program version.') do
          puts VERSION
          exit
        end        
      end
    end
  end # OptParser
end # Shalmaneser
