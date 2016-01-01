module Shalmaneser
  module Fred
    ####################################
    # grammatical function computation:
    # given a sentence, keep all grammatical function relations in a hash
    # for faster access
    class GrammaticalFunctionAccess
      def initialize(interpreter_class)
        @interpreter_class = interpreter_class
        @to = Hash.new([])
        @from = Hash.new([])
      end

      # SalsaTigerRegXML sentence
      def set_sent(sent)
        @to.clear
        @from.clear

        sent.each_syn_node do |current|
          current_head = @interpreter_class.head_terminal(current)
          next unless current_head

          @interpreter_class.gfs(current, sent).map do |rel, node|
            # PPs: use head noun rather than preposition as head
            # Sbar, VP: use verb
            if (n = @interpreter_class.informative_content_node(node))
              [rel, n]
            else
              [rel, node]
            end
          end.each do |rel, node|
            rel_head = @interpreter_class.head_terminal(node)
            next unless rel_head

            unless @to.key? current_head
              @to[current_head] = []
            end

            unless @to[current_head].include? [rel, rel_head]
              @to[current_head] << [rel, rel_head]
            end

            unless @from.key?(rel_head)
              @from[rel_head] = []
            end

            unless @from[rel_head].include? [rel, current_head]
              @from[rel_head] << [rel, current_head]
            end
          end
        end
      end

      def get_children(node)
        @to[node]
      end

      def get_parents(node)
        @from[node]
      end
    end
  end
end
