require 'fred/targets'

module Shalmaneser
  module Fred
    ########################################
    class FindTargetsFromFrames < Targets
      ###
      # determine_targets:
      # use existing frames to find targets
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
      def determine_targets(st_sent) #SalsaTigerSentence object
        retv = {}
        st_sent.each_frame { |frame_obj|
          # instance-specific computation:
          # target and target positions
          # WARNING: at this moment, we are
          # not considering true multiword targets for German.
          # Remove the "no_mwe" parameter in main_node_of_expr
          # to change this
          term = nil
          all_targets = nil
          if frame_obj.target.nil? or frame_obj.target.children.empty?
          # no target, nothing to record

          elsif @exp.get("language") == "de"
            # don't consider true multiword targets for German
            all_targets = frame_obj.target.children
            term = @interpreter_class.main_node_of_expr(all_targets, "no_mwe")

          else
            # for all other languages: try to figure out the head target word
            # anyway
            all_targets = frame_obj.target.children
            term = @interpreter_class.main_node_of_expr(all_targets)
          end

          if term and term.is_splitword?
            # don't use parts of a word as main node
            term = term.parent
          end
          if term and term.is_terminal?
            key = [all_targets.map { |t| t.id }, term.id]

            unless retv[key]
              retv[key] = []
            end

            pos = frame_obj.target.get_attribute("pos")
            # gold POS available, may be in wrong form,
            # i.e. not the same strings that @interpreter_class.category()
            # would return
            case pos
            when /^[Vv]$/
              pos = "verb"
            when /^[Nn]$/
              pos = "noun"
            when /^[Aa]$/
              pos = "adj"
            when nil
              pos = @interpreter_class.category(term)
            end

            target_info = {
              "sense" => frame_obj.name,
              "obj" => frame_obj,
              "all_targets" => frame_obj.target.children.map { |ch| ch.id },
              "lex" => frame_obj.target.get_attribute("lemma"),
              "pos" => pos,
              "sid" => st_sent.id
            }
            #print "lex ", frame_obj.target(), " und ",frame_obj.target().get_attribute("lemma"), "\n"
            retv[key] << target_info
            if @record_targets
              record(target_info)
            end
          end
        }
        return retv
      end
    end
  end
end
