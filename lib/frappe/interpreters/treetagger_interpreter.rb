###############
# an interpreter that only has Treetagger, no parser

require_relative 'syn_interpreter'

module Shalmaneser
  module Frappe
    class TreetaggerInterpreter < SynInterpreter
      TreetaggerInterpreter.announce_me

      ###
      # names of the systems interpreted by this class:
      # returns a hash service(string) -> system name (string),
      # e.g.
      # { "parser" => "collins", "lemmatizer" => "treetagger" }
      def self.systems
        {"pos_tagger" => "treetagger"}
      end

      ###
      # names of additional systems that may be interpreted by this class
      # returns a hash service(string) -> system name(string)
      # same as names()
      def self.optional_systems
        {"lemmatizer" => "treetagger"}
      end

      ###
      # generalize over POS tags.
      #
      # returns one of:
      #
      # adj:  adjective (phrase)
      # adv:  adverb (phrase)
      # card: numbers, quantity phrases
      # con:  conjunction
      # det:  determiner, including possessive/demonstrative pronouns etc.
      # for:  foreign material
      # noun: noun (phrase), including personal pronouns, proper names, expletives
      # part: particles, truncated words (German compound parts)
      # prep: preposition (phrase)
      # pun:  punctuation, brackets, etc.
      # sent: sentence
      # top:  top node of a sentence
      # verb: verb (phrase)
      # nil:  something went wrong
      #
      # returns: string, or nil
      def self.category(node) # SynNode
        pt = TreetaggerInterpreter.pt(node)
        # phrase type could not be determined
        return nil if pt.nil?

        case pt.to_s.strip.match(/^([^-]*)/)[1]
        when /^JJ/, /(WH)?ADJP/, /^PDT/
          "adj"
        when /^RB/, /(WH)?ADVP/, /^UH/
          "adv"
        when /^CD/, /^QP/
          "card"
        when /^CC/, /^WRB/, /^CONJP/
          "con"
        when /^DT/, /^POS/
          "det"
        when /^FW/, /^SYM/
          "for"
        when /^N/, "WHAD", "WDT", /^PRP/, /^WHNP/, /^EX/, /^WP/
          "noun"
        when /^IN/, /^TO/, /(WH)?PP/, "RP", /^PR(T|N)/
          "prep"
        when /^PUNC/, /LRB/, /RRB/, /[,'".:;!?\(\)]/
          "pun"
        when /^S(s|bar|BAR|G|Q|BARQ|INV)?$/, /^UCP/, /^FRAG/, /^X/, /^INTJ/
          "sent"
        when /^TOP/
          "top"
        when /^TRACE/
          "trace"
        when /^V/, /^MD/
          "verb"
        else
          # @todo Change this to a Logger warning.
          STDERR.puts "WARNING: Unknown category/POS " + pt.to_s + " (English data)."
          nil
        end
      end
    end
  end
end
