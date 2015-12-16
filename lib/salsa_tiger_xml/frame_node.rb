require_relative 'sem_node'

#############
# class FrameNode
#
# inherits from SemNode
# adds to it methods specific to nodes
# that describe a frame
#
# additional/changed methods:
#
# name      returns the name of the frame
# set_name  changes the name of the frame to a new name
# target    returns the target (as a FeNode object)
#
# each_child() iterates through FEs, children() returns all FEs
#
# each_fe_by_name A frame node may have several FE children with the same
#           frame element label. While each_child returns them separately,
#           each_fe_by_name lumps FE children with the same frame element label
#           into one FeNode.
#           Warnings:
#           - the REXML object of the FeNode is that of the first FE child
#             with that frame element label.
#           - Underspecification is ignored! If you have the same FE twice,
#             and there is underspecification regarding the extent of the FE,
#             the two FE children will be lumped together anyway.
#             If you don't want that, use each_child instead.
#
#
# add_fe CAUTION: please do not call this method directly externally,
#           use SalsaTigerSentence.add_fe, otherwise the node and its ID
#           will not be recorded in the node list and the node cannot be retrieved
#           via its ID

class FrameNode < SemNode
  ###
  def target
    target = children_by_edgelabels(["target"])
    if target.empty?
      $stderr.puts "SalsaTigerRegXML warning: Frame #{id}: No target, but I got: \n" + child_labels.join(", ")
      return nil
    else
      unless target.length == 1
        raise "Target: more than one target to frame #{id}."
      end
      return target.first
    end
  end

  ###
  def name
    get_attribute("name")
  end

  ###
  def set_name(new_name)
    set_attribute("name", new_name)
  end

  ###
  # each_fe: synonym for each_child
  def each_fe
    each_child { |c| yield c }
  end

  ###
  # fes: synonym for children
  def fes
    children
  end

  ###
  def each_fe_by_name
    child_labels.uniq.each { |fe_name|
      unless fe_name == "target"

        fes = children_by_edgelabels([fe_name])

        if fes.length == 1
          # one frame element with that name
          yield fes.first

        else
          # several frame elements with that name
          # combine them

          combined_fe = FeNode.new(fe_name, "#{id}_#{fe_name}")
          fes.each { |fe|
            fe.each_child { |child|
              combined_fe.add_child(child)
            }
          }
          yield combined_fe
        end
      end
    }
  end

  ###
  def add_child(fe_node)
    if fe_node.name == "target" and not(children_by_edgelabels(["target"]).empty?)
      $stderr.puts "Adding second target to frame #{id}"
      $stderr.puts "I already have: " + children_by_edgelabels(["target"]).map { |t| t.id }.join(",")
      raise "More than one target."
    end

    super(fe_node, fe_node.name)
  end

  ###
  def remove_child(fe_node)
    super(fe_node, fe_node.name)
  end

  ###
  def add_fe(fe_name,   # string: name of FE to add
             syn_nodes, # array:SynNode, syntactic nodes that this FE should point to
             fe_id = nil) # string: ID for the new FE

    if fe_name == "target" && not(children_by_edgelabels(["target"]).empty?)
      $stderr.puts "Adding second target to frame #{id}"
      $stderr.puts "I already have: " + children_by_edgelabels(["target"]).map(&:id).join(",")
      raise "More than one target."
    end

    # make FE node and list as this frame's child
    unless fe_id
      # no FE ID given, make one myself
      fe_id = id + "_fe" + Time.new.to_f.to_s
    end

    n = FeNode.new(fe_name, fe_id)
    add_child(n)

    # add syn nodes
    syn_nodes.each { |syn_node|
      n.add_child(syn_node)
    }

    n
  end
end
