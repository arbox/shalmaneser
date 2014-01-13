require 'optparse'
require 'shalmaneser/version'


module Shalmaneser
  class OptParser
    
    # Specify a default option first.
    ENCODINGS = %w{iso utf8 hex}
    LANGUAGES = %w{de en}
    PARSERS   = %w{BerkeleyParser StanfordParser CollinsParser}

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
        opts.banner = "CAUTION: Shalmaneser DOES NOT work in Enduser Mode for now!\n" +
          'Usage: shalmaneser -i path [-o path -e enc -l lang -p parser]'
        opts.separator ''
        opts.separator 'Mandatory options:'
        opts.on('-i', '--input INPUTPATH', String,
                'Path to directory with input files.')
        opts.separator ''

        opts.separator 'Facultative options:'
        opts.on('-o', '--output OUTPUTPATH', String,
                'Path to directory for output files.',
                'If not set it defaults to <users home directory>.')
        opts.on('-e', '--encoding ENCODING', ENCODINGS,
                "Encoding of input files. Allowed encodings are: #{ENCODINGS.join(', ')}.",
                "If not set it defaults to <#{ENCODINGS.first}>.")
        opts.on('-l', '--language LANGUAGE', LANGUAGES,
                "Language to be processed. Allowed language are: #{LANGUAGES.join(', ')}.",
                "If not set it defaults to <#{LANGUAGES.first}>.")
        opts.on('-p', '--parser PARSER', PARSERS,
                "Parser name you want to use.",
                "Implemented parsers are: #{PARSERS.join(', ')}.",
                "If not set it defaults to <#{PARSERS.first}>.")
        opts.on('--visualize', 'Open output files with SALTO.',
                'This is ignored if SALTO is not found on your system.')

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
