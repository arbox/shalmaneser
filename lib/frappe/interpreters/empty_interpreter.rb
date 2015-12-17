# @note AB: This interpreter is used by Rosy.
#   Don't know what for.
module Shalmaneser
  module Frappe
    class EmptyInterpreter < SynInterpreter
      EmptyInterpreter.announce_me

      ###
      # systems interpreted by this class:
      # returns a hash service(string) -> system name (string),
      # e.g.
      # { "parser" => "collins", "lemmatizer" => "treetagger" }
      def self.systems
        {}
      end

      ###
      # names of additional systems that may be interpreted by this class
      # returns a hash service(string) -> system name(string)
      # same as names()
      def SynInterpreter.optional_systems
        {}
      end
    end
  end
end
