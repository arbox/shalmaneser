require 'fred/word_lemma_pos_ne'
require 'salsa_tiger_xml/salsa_tiger_sentence'
require 'tabular_format/tab_format_sentence'

module Shalmaneser
  module Fred

    ########################################
    # Context Provider classes:
    # read in text, collecting context windows of given size
    # around target words, yield contexts as soon as they are complete
    #
    # Target words are determined by delegating to either TargetsFromFrames or AllTargets
    #
    class AbstractContextProvider

      include WordLemmaPosNe

      ################
      def initialize(window_size, # int: size of context window (one-sided)
                     exp,         # experiment file object
                     interpreter_class, #SynInterpreter class
                     target_obj,  # AbstractTargetDeterminer object
                     dataset)     # "train", "test"

        @window_size = window_size
        @exp = exp
        @interpreter_class = interpreter_class
        @target_obj = target_obj
        @dataset = dataset

        # make arrays:
        # context words
        @context = Array.new(2 * @window_size + 1, nil)
        # nil for non-targets, all information on the target for targets
        @is_target = Array.new(2 * @window_size + 1, nil)
        # sentence object
        @sentence = Array.new(2 * @window_size + 1, nil)

      end

      ###################
      # each_window: iterator
      #
      # given a directory with Salsa/Tiger XML data,
      # iterate through the data,
      # yielding each target word as soon as its context window is filled
      # (or the last file is at an end)
      #
      # yields tuples of:
      # - a context, an array of tuples [word,lemma, pos, ne]
      #   string/nil*string/nil*string/nil*string/nil
      # - ID of main target: string
      # - target_IDs: array:string, list of IDs of target words
      # - senses: array:string, the senses for the target
      # - sent: SalsaTigerSentence object
      def each_window(dir) # string: directory containing Salsa/Tiger XML data
        raise "overwrite me"
      end

      ####################
      protected

      ############################
      # shift a sentence through the @context window,
      # yield when at target
      #
      # yields tuples of:
      # - a context, an array of tuples [word,lemma, pos, ne]
      #   string/nil*string/nil*string/nil*string/nil
      # - ID of main target: string
      # - target_IDs: array:string, list of IDs of target words
      # - senses: array:string, the senses for the target
      # - sent: SalsaTigerSentence object
      def each_window_for_sent(sent)  # SalsaTigerSentence object or TabSentence object
        if sent.is_a? STXML::SalsaTigerSentence
          each_window_for_stsent(sent) { |result| yield result }

        elsif sent.is_a? TabFormatSentence
          each_window_for_tabsent(sent) { |result | yield result }

        else
          $stderr.puts "Error: got #{sent.class}, expected SalsaTigerSentence or TabFormatSentence."
          exit 1
        end
      end

      ###
      # sent is a SalsaTigerSentence object:
      # there may be targets
      #
      # yields tuples of:
      # - a context, an array of tuples [word,lemma, pos, ne]
      #   string/nil*string/nil*string/nil*string/nil
      # - ID of main target: string
      # - target_IDs: array:string, list of IDs of target words
      # - senses: array:string, the senses for the target
      # - sent: SalsaTigerSentence object
      def each_window_for_stsent(sent)
        # determine targets first.
        # original targets:
        #  hash: target_IDs -> list of senses
        #   where target_IDs is a pair [list of terminal IDs, main terminal ID]
        #
        #  where a sense is represented as a hash:
        #  "sense": sense, a string
        #  "obj":   FrameNode object
        #  "all_targets": list of node IDs, may comprise more than a single node
        #  "lex":   lemma, or multiword expression in canonical form
        #  "sid": sentence ID
        original_targets = @target_obj.determine_targets(sent)


        # reencode, make hashes:
        # main target ID -> list of senses,
        # main target ID -> all target IDs
        maintarget_to_senses = {}
        main_to_all_targets = {}
        original_targets.each_key { |alltargets, maintarget|

          main_to_all_targets[maintarget] = alltargets
          maintarget_to_senses[maintarget] = original_targets[[alltargets, maintarget]]

        }

        # then shift each terminal into the context window
        # and check whether there is a target at the center
        # position
        sent_terminals_nopunct(sent).each { |term_obj|
          # add new word to end of context array
          @context.push(word_lemma_pos_ne(term_obj, @interpreter_class))

          if maintarget_to_senses.has_key? term_obj.id
            @is_target.push( [ term_obj.id,
                               main_to_all_targets[term_obj.id],
                               maintarget_to_senses[term_obj.id]
                             ]  )
          else
            @is_target.push(nil)
          end

          @sentence.push(sent)

          # remove first word from context array
          @context.shift
          @is_target.shift
          @sentence.shift

          # check for target at center
          if @is_target[@window_size]
            # yes, we have a target at center position.
            # yield it:
            # - a context, an array of tuples [word,lemma, pos, ne]
            #   string/nil*string/nil*string/nil*string/nil
            # - ID of main target: string
            # - target_IDs: array:string, list of IDs of target words
            # - senses: array:string, the senses for the target
            # - sent: SalsaTigerSentence object
            main_target_id, all_target_ids, senses = @is_target[@window_size]

            yield [ @context,
                    main_target_id, all_target_ids,
                    senses,
                    @sentence[@window_size]
                  ]
          end
        }
      end

      ###
      # sent is a TabFormatSentence object.
      # shift word/lemma/pos/ne tuples throught the context window.
      # Whenever this brings a target (from another sentence, necessarily)
      # to the center of the context window, yield it.
      def each_window_for_tabsent(sent)
        sent.each_line_parsed { |line_obj|
          # push onto the context array:
          # [word, lemma, pos, ne], all lowercase
          @context.push([ line_obj.get("word").downcase,
                          line_obj.get("lemma").downcase,
                          line_obj.get("pos").downcase,
                          nil])
          @is_target.push(nil)
          @sentence.push(nil)

          # remove first word from context array
          @context.shift
          @is_target.shift
          @sentence.shift

          # check for target at center
          if @is_target[@window_size]
            # yes, we have a target at center position.
            # yield it:
            # context window, main target ID, all target IDs,
            # senses (as FrameNode objects), sentence as XML
            main_target_id, all_target_ids, senses = @is_target[@window_size]
            yield [ @context,
                    main_target_id, all_target_ids,
                    senses,
                    @sentence[@window_size]
                  ]
          end
        }
      end

      ############################
      # each remaining target:
      # call this to empty the context window after everything has been shifted in
      def each_remaining_target
        while @context.detect { |entry| not(entry.nil?) }
          # push nil on the context array
          @context.push(nil)
          @is_target.push(nil)
          @sentence.push(nil)

          # remove first word from context array
          @context.shift
          @is_target.shift
          @sentence.shift

          # check for target at center
          if @is_target[@window_size]
            # yes, we have a target at center position.
            # yield it:
            # context window, main target ID, all target IDs,
            # senses (as FrameNode objects), sentence as XML
            main_target_id, all_target_ids, senses = @is_target[@window_size]
            yield [ @context,
                    main_target_id, all_target_ids,
                    senses,
                    @sentence[@window_size]
                  ]
          end
        end
      end
      ############################
      # helper: remove punctuation
      def sent_terminals_nopunct(sent)
        return sent.terminals_sorted.reject { |node|
          @interpreter_class.category(node) == "pun"
        }
      end
    end
  end
end
