require "Graph.rb"

class TreeNode < GraphNode

  def initialize(id)
    super(id)
  end

  # redo the ancestor-related methods,
  # since here we only have one parent per node
  def parent()
    retv = parents()
    if retv.nil?
      return nil
    else
      return retv.first
    end
  end

  def parent_label()
    retv = parent_labels()
    if retv.nil?
      return nil
    else
      return retv.first
    end
  end
 

  def parent_with_edgelabel()
    retv = parents_with_edgelabel()

    if retv.nil?
      return nil
    else
      return retv.first
    end
  end


  def add_parent(parent, edgelabel, varhash={})
    set_parent(parent, edgelabel, varhash)
  end

  def set_parent(parent, edgelabel, varhash={})
    # remove old parent
    each_parent_with_edgelabel { |label, parent|
      remove_parent(parent, label, varhash)
    }

    # set new parent
    @parents << [edgelabel, parent]

    # and vice versa: add self as child to parent
    unless varhash["pointer_insteadof_edge"]
      unless parent.children_with_edgelabel().include? [edgelabel, self]
        parent.add_child(self, edgelabel)
      end
    end
  end
end
