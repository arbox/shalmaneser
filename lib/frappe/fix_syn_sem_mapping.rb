###
# FixSynSemMapping:
# Given a SalsaTigerRegXML sentence with semantic role annotation,
# simplify the mapping of semantic roles to syntactic constituents
#
# The following is lifted from the LREC06 paper on Shalmaneser:
# During preprocessing, the span of semantic roles in the training corpora is
# projected onto the output of the syntactic parser by assigning each
# role to the set of maximal constituents covering its word span.
# f the word span of a role does not coincide
# with parse tree constituents, e.g. due to misparses,
# the role is ``spread out'' across several constituents. This leads to
# idiosyncratic paths between predicate and semantic role in the parse
# tree.
#
# [The following span standardization algorithm is used to make the
# syntax-semantics mapping more uniform:]
# Given a role r that has been assigned, let N be the set of
# terminal nodes of the syntactic structure that are covered by r.
#
#   Iteratively compute the maximal projection of N in the syntactic
#   structure:
#   1) If n is a node such that all of n's children are in N,
#     then remove n's children from N and add n instead.
#   2) If n is a node with 3 or more children, and all of n's
#     children except one are in N, then remove n's children from N
#     and add n instead.
#   3) If n is an NP with 2 children, and one of them, another NP,
#     is in N, and the other, a relative clause, is not, then remove
#     n's children from N and add n instead.
#
#   If none of the rules is applicable to N anymore, assign r to the
#   nodes in N.
#
# Rule 1 implements normal maximal projection. Rule 2 ``repairs'' parser
# errors where all children of a node but one have been assigned the
# same role. Rule 3 addresses a problem of the FrameNet data, where
# relative clauses have been omitted from roles assigned to NPs.

# KE Feb 08: rule 3 currently out of commission!

# require "common/SalsaTigerRegXML"

module FixSynSemMapping
  ##
  # fix it
  #
  # relevant settings in the experiment file:
  #
  # fe_syn_repair:
  # If there is a node that would be a max. constituent for the
  # words covered by the given FE, except that it has one child
  # whose words are not in the FE, use the node as max constituent anyway.
  # This is to repair cases where the parser has made an attachment choice
  # that differs from the one in the gold annotation
  #
  # fe_rel_repair:
  # If there is an NP such that all of its children except one have been
  # assigned the same FE, and that missing child is a relative clause
  # depending on one of the other children, then take the complete NP as
  # that FE
  def FixSynSemMapping.fixit(sent, # SalsaTigerSentence object
                             exp,  # experiment file object
                             interpreter_class) # SynInterpreter class


    unless exp.get("fe_syn_repair") or exp.get("fe_rel_repair")
      return
    end

    if sent.nil?
	return
    end

    # "repair" FEs:
    sent.each_frame { |frame|

      frame.each_child { |fe_or_target|

        # repair only if the FE currently
        # points to more than one syn node
        if fe_or_target.children.length() < 2
          next
        end

        if exp.get("fe_rel_repair")
          lastfe = fe_or_target.children.last()
          if lastfe and interpreter_class.simplified_pt(lastfe) =~ /^(WDT)|(WP\$?)|(WRB)/

            # remove syn nodes that the FE points to
            old_fe_syn = fe_or_target.children()
            old_fe_syn.each { |child|
              fe_or_target.remove_child(child)
            }

            # set it to point only to the last previous node, the relative pronoun
            fe_or_target.add_child(lastfe)
          end
        end

        if exp.get("fe_syn_repair")
          # remove syn nodes that the FE points to
          old_fe_syn = fe_or_target.children()
          old_fe_syn.each { |child|
            fe_or_target.remove_child(child)
          }

          # and recompute
          new_fe_syn = interpreter_class.max_constituents(old_fe_syn.map { |t|
                                                            t.yield_nodes
                                                          }.flatten.uniq,
                                                          sent,
                                                          exp.get("fe_syn_repair"))

          # make the FE point to the new nodes
          new_fe_syn.each { |syn_node|
            fe_or_target.add_child(syn_node)
          }
        end
      } # each FE
    } # each frame
  end # def fixit
end # module


#########3
# old code

#     if exp.get("fe_rel_repair")
#       # repair relative clauses:
#       # then make a procedure to pass on to max constituents
#       # that will recognize the relevant cases

#       accept_anyway_proc = Proc.new { |node, children_in, children_out|

#         # node: SynNode
#         # children_in, children_out: array:SynNode. children_in are the children
#         #    that are already covered by the FE, children_out the ones that aren't

#         # if node is an NP,
#         # and only one of its children is out,
#         # and one node in children_in is an NP, and the missing child is an SBAR
#         # with a child that is a relative pronoun, then consider the child in children_out as covered
#         if interpreter_class.category(node) == "noun" and
#             children_out.length() == 1 and
#             children_in.select { |n| interpreter_class.category(n) == "noun" } and
#             interpreter_class.category(children_out.first) == "sent" and
#             (ch = children_out.first.children) and
#             ch.select { |n| interpreter_class.relative_pronoun?(n) }
#           true
#         else
#           false
#         end
#       }

#     else
#       accept_anyway_proc = nil
#     end


#     # "repair" FEs:
#     sent.each_frame { |frame|

#       frame.each_child { |fe_or_target|

#         # repair only if the FE currently
#         # points to more than one syn node, or
#         # if it is a noun with a non-covered sentence sister
#         if fe_or_target.children.length() > 1 or
#             (exp.get("fe_rel_repair") and (curr_marked = fe_or_target.children.first())  and
#              interpreter_class.category(curr_marked) == "noun" and
#              (p = curr_marked.parent) and
#              p.children.select { |n| n != curr_marked and interpreter_class.category(n) == "sent" } )

#           # remember nodes covered by the FE
#           old_fe_syn = fe_or_target.children()

#           # remove syn nodes that the FE points to
#           old_fe_syn.each { |child|
#             fe_or_target.remove_child(child)
#           }

#           # and recompute
#           new_fe_syn = interpreter_class.max_constituents(old_fe_syn.map { |t| t.yield_nodes}.flatten.uniq,
#                                                           sent,
#                                                           exp.get("fe_syn_repair"),
#                                                           accept_anyway_proc)

#           # make the FE point to the new nodes
#           new_fe_syn.each { |syn_node|
#             fe_or_target.add_child(syn_node)
#           }

#         end # if FE points to more than one syn node
#       } # each FE
#     } # each frame
