require 'fred/targets'

module Shalmaneser
  module Fred
    ########################################
    class FindAllTargets < Targets
      ###
      # determine_targets:
      # use all known lemmas, minus stopwords
      def initialize(exp,
                     interpreter_class)
        # read target info from file
        super(exp, interpreter_class, "r")
        @training_lemmapos_pairs = get_lemma_pos

        get_senses(@training_lemmapos_pairs)
        # list of words to exclude from assignment, for now
        @stoplemmas = [
          "have",
          "do",
          "be"
          #      "make"
        ]

      end

      ####
      #
      # returns:
      #  hash: target_IDs -> list of senses
      #   where target_IDs is a pair [list of terminal IDs, main terminal ID]
      #
      #  where a sense is represented as a hash:
      #  "sense": sense, a string
      #  "obj":   FrameNode object
      #  "all_targets": list of node IDs, may comprise more than a single node
      #  "lex":   lemma, or multiword expression in canonical form
      #  "sid": sentence ID
      def determine_targets(sent) #SalsaTigerSentence object
        # map target IDs to list of senses, in our case always [ nil ]
        # because we assume that the senses of the targets we point out
        # are unknown
        retv = {}
        # iterate through terminals of the sentence, check for inclusion
        # of their lemma in @training_lemmas
        sent.each_terminal { |node|
          # we know this lemma from the training data,
          # and it is not an auxiliary,
          # and it is not in the stopword list
          # and the node does not represent a preposition

          ### modified by ines, 17.10.2008
          lemma = @interpreter_class.lemma_backoff(node)
          pos = @interpreter_class.category(node)

          #     print "lemma ", lemma, " pos ", pos, "\n"
          #      reg = /\.[ANV]/
          #      if !reg.match(lemma)
          #        if /verb/.match(pos)
          #          lemma = lemma + ".V"
          #        elsif /noun/.match(pos)
          #          lemma = lemma + ".N"
          #        elsif /adj/.match(pos)
          #          lemma = lemma + ".A"
          #        end
          #        print "LEMMA ", lemma, " POS ", pos, "\n"
          #      end

          if (@training_lemmapos_pairs.include? [lemma, pos] and
              not(@interpreter_class.auxiliary?(node)) and
              not(@stoplemmas.include? lemma) and
              not(pos == "prep"))
            key = [ [ node.id ], node.id ]

            # take this as a target.
            retv[ key ] = [
              {
                "sense" => nil,
                "obj" => nil,
                "all_targets" => [ node.id ],
                "lex" => lemma,
                "pos" => pos,
                "sid" => sent.id
              } ]
            # no recording of target info,
            # since we haven't determined anything new
          end
        }

        return retv
      end
    end
  end
end
