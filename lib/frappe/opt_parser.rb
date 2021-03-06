# -*- encoding: utf-8 -*-

# @author AB
# @date 2010-11-25

require 'optparse'
require 'configuration/frappe_config_data'
require 'definitions'
require 'external_systems'
require 'logging'

module Shalmaneser
  module Frappe
    # This class parses options for FrPrep.
    # @todo Remove explicit exits in this class.
    class OptParser
      # Main class method.
      # OP expects cmd_args to be an array like ARGV.
      def self.parse(cmd_args)
        @prg_name = PROGRAM_NAME
        @options = {}
        parser = create_parser

        # If no options provided print the help.
        if cmd_args.empty?
          msg = "You have to provide some options.\n"\
                "Please start with <#{@prg_name} --help>."

          $stderr.puts msg
          exit(1)
        end

        # Parse ARGV and provide the options hash.
        # Check if everything is correct and handle exceptions
        begin
          parser.parse(cmd_args)
        rescue OptionParser::InvalidArgument => e
          arg = e.message.split.last
          $stderr.puts "The provided argument #{arg} is currently not supported!\n"\
                       "Please consult <#{@prg_name} --help>."
          exit(1)
        rescue OptionParser::InvalidOption => e
          $stderr.puts "You have provided an #{e.message}.\n"\
                       "Please consult <#{@prg_name} --help>."
          exit(1)
        rescue
          raise
        end

        # @todo Rename the config data class.
        exp = ::Shalmaneser::Configuration::FrappeConfigData.new(@options[:exp_file])

        # @todo AB: [2015-12-28 Mon 19:22]
        #   Move this to ConfigData.
        ExternalSystems.check_interfaces_abort_if_missing(exp)

        exp
      end

      private

      def self.create_parser
        OptionParser.new do |opts|
          opts.banner = "Fred and Rosy Preprocessor <Frappe>. Preprocessing stage before Fred and Rosy\n"\
                        "for further frame/word sense disambiguation and semantic role assignment."\
                        "\n"\
                        "Usage: #{PROGRAM_NAME.downcase} -h|-e FILENAME"
          opts.separator ''
          opts.separator 'Program specific options:'

          opts.on('-e', '--expfile FILENAME',
                  'Provide the path to an experiment file.',
                  "#{PROGRAM_NAME} will preprocess data according to the specifications",
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
  end # module Frappe
end # Shalm
