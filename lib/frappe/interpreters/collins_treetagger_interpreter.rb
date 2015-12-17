require_relative 'collins_tnt_interpreter'

module Shalmaneser
  module Frappe
    # @todo AB: [2015-12-17 Thu 21:26]
    #   Remove this class and rewrite CollinTntInterpreter.
    #   This class does nothing.
    class CollinsTreeTaggerInterpreter < CollinsTntInterpreter
      CollinsTreeTaggerInterpreter.announce_me

      def self.systems
        {"pos_tagger" => "treetagger", "parser" => "collins"}
      end
    end
  end
end
