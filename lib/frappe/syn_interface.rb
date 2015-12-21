#############################
# abstract class, to be inherited:
#
# tabular format or SalsaTigerXML interface for modules
# offering POS tagging, lemmatization, parsing etc.

# Leave this commented until we've reworked SynInterfaces
# since in causes circular requirements.
# require 'syn_interfaces'

module Shalmaneser
  module Frappe
    class SynInterface
      ###
      # returns a string: the name of the system
      # e.g. "Collins" or "TNT"
      def self.system
        raise NotImplementedError, "Overwrite me"
      end

      ###
      # returns a string: the service offered
      # one of "lemmatizer", "parser", "pos tagger"
      def self.service
        raise NotImplementedError, "Overwrite me"
      end

      ###
      # initialize to set values for all subsequent processing
      def initialize(program_path, # string: path to system
                     insuffix,      # string: suffix of input files
                     outsuffix,     # string: suffix for processed files
                     var_hash = {}) # optional arguments in a hash

        @program_path = program_path
        @insuffix = insuffix
        @outsuffix = outsuffix
      end

      ###
      # process each file in in_dir with matching suffix,
      # producing a file in out_dir with same name but the suffix replaced
      #
      # returns: nothing
      def process_dir(in_dir,        # string: name of input directory
                      out_dir)       # string: name of output directory

        Dir["#{in_dir}*#{@insuffix}"].each do |infilename|
          outfilename = "#{out_dir}#{File.basename(infilename, @insuffix)}#{@outsuffix}"
          process_file(infilename, outfilename)
        end
      end

      ###
      # process one file, writing the result to outfilename
      #
      # returns: nothing
      def process_file(infilename,   # string: name of input file
                       outfilename)
        raise NotImplementedError, "Overwrite me"
      end

      protected

      def self.announce_me
        if defined?(SynInterfaces)
          # Yup, we have a class to which we can announce ourselves.
          SynInterfaces.add_interface(self)
        else
          # no interface collector class
          LOGGER.warn "Interface #{self} not announced: no SynInterfaces."
        end
      end
    end
  end
end
