# GraphNode: describes one node in a graph.
#
# A node may have an arbitrary number of parents (sources of incoming edges)
# and an arbitrary number of children (targets of outgoing edges)
#
# All edges are labeled and directed
#
# The add_parent, add_child, remove_parent, remove_child methods
# take care of both ends of an edge 
# (i.e. n1.add_child(n2, label) also adds n1 as parent of n2 with edge label 'label'
#
# It is possible to create a 'pointer' rather than an edge:
#     n1.add_child(n2, label, pointer_insteadof_edge => true) 
# will create an edge from n1 to n2 labeled 'label' that is
# listed under the outgoing edges of n1, but not among
# the incoming edges of n2
# The same option is available for add_parent, remove_parent, remove_child.

class GraphNode

  def initialize(id)
    @id = id
    @children = Array.new
    @parents = Array.new
    @features = Hash.new
  end

  # for Marshalling: 
  # Dump just IDs instead of actual nodes from Parents and Children lists.
  # Otherwise the Marshaller will go crazy following
  # all the links to objects mentioned.
  # After loading: replace IDs by actual objects with a little help
  # from the caller.

  def _dump(depth)
    @id.to_s +
      "QQSEPVALUESQQ" +
      Marshal.dump(@features) +
      "QQSEPVALUESQQ" +
      @children.map { |label_child| 
        label_child[0] + "QQSEPQQ" + label_child[1].id()
      }.join("QQPAIRQQ") +
      "QQSEPVALUESQQ" +
      @parents.map { |label_parent|
        label_parent[0] + "QQSEPQQ" + label_parent[1].id()
    }.join("QQPAIRQQ")      
  end

  def GraphNode._load(string)
    id, features_s, children_s, parents_s =
      string.split("QQSEPVALUESQQ")

    result = GraphNode.new(id)
    result.fill_from_pickle(string)
    return result
  end

  def fill_from_pickle(string)
    id, features_s, children_s, parents_s =
      string.split("QQSEPVALUESQQ")

    @features = Marshal.load(features_s)

    if children_s.nil? or children_s.empty?
      @children = []
    else
      @children = children_s.split("QQPAIRQQ").map { |pair|
	pair.split("QQSEPQQ")
      }
    end

    if parents_s.nil? or parents_s.empty?
      @parents = []
    else
      @parents = parents_s.split("QQPAIRQQ").map { |pair|
	pair.split("QQSEPQQ")
      }
    end
  end

  def recover_from_dump(node_by_id)
    @children = @children.map { |label_id| [label_id[0], node_by_id.call(label_id[1])] }
    @parents = @parents.map { |label_id| [label_id[0], node_by_id.call(label_id[1])] }
  end

  # ID-related things

  def ==(other_node)
    unless other_node.kind_of? GraphNode
      return false
    end
    @id == other_node.id()
  end

  def id()
    return @id
  end

  def chid(newid)
    @id = newid
  end

  # setting and retrieving features

  def get_f(feature)
    return @features[feature]
  end

  def set_f(feature, value)
    @features[feature] = value
  end

  def add_f(feature, value)
    unless @features[feature].nil?
      raise "Feature " + feature + "already set."
    end
    set_f(feature, value)
  end
  
  # ancestors 

  def parents()
    return @parents.map { |label_parent| 
      label_parent[1] }
  end
  
  def parent_labels()
    return @parents.map { |label_parent| label_parent[0] }
  end

  def parent_label(parent)
    @parents.each { |label_parent|
      if label_parent[1] == parent 
	return label_parent[0]
      end
    }
    return nil
  end

  def parents_with_edgelabel()
    return @parents
  end

  def each_parent()
    @parents.each { |label_parent| yield label_parent[1] }
  end

  def each_parent_with_edgelabel()
    @parents.each { |label_parent| yield label_parent}
  end

  def parents_by_edgelabels(labels)
    return @parents.select { |label_parent|
      labels.include? label_parent[0]
    }.map { |label_parent|
      label_parent[1]
    }
  end

  def add_parent(parent, edgelabel, varhash={})
    @parents << [edgelabel, parent]

    # and vice versa: add self as child to parent
    unless varhash["pointer_insteadof_edge"]
      unless parent.children_with_edgelabel().include? [edgelabel, self]
        parent.add_child(self, edgelabel)
      end
    end
  end

  def remove_parent(parent, edgelabel, varhash={})
    @parents = @parents.reject { |label_child| 
      label_child.first == edgelabel and
	label_child.last == parent
    }

    # and vice versa: remove self as child from parent
    unless varhash["pointer_insteadof_edge"]
      if parent.children_with_edgelabel().include? [edgelabel, self]
        parent.remove_child(self, edgelabel)
      end
    end
  end

  def indeg()
    return @parents.length()
  end

  def ancestors
    return ancestors_noduplicates([], [])
  end

  def ancestors_by_edgelabels(labels)
    return ancestors_noduplicates([], labels)
  end

  # descendants

  def children()
    return @children.map { |label_child| label_child[1] }
  end

  def child_labels()
    return @children.map { |label_child| label_child[0] }
  end

  def child_label(child)
    @children.each { |label_child|
      if label_child[1] == child
	return label_child[0]
      end
    }
    return nil
  end

  def children_with_edgelabel()
    return @children
  end

  def each_child()
    @children.each { |label_child| yield label_child[1]}
  end

  def each_child_with_edgelabel()
    @children.each { |label_child| yield label_child } 
  end

  def children_by_edgelabels(labels)
    return @children.select { |label_child|
      labels.include? label_child[0] 
    }.map { |label_child|
      label_child[1]
    }
  end

  def add_child(child, edgelabel, varhash={})
    @children << [edgelabel, child]

    # and vice versa: add self as parent to child
    unless varhash["pointer_insteadof_edge"]
      unless child.parents_with_edgelabel().include? [edgelabel, self]
        child.add_parent(self, edgelabel)
      end
    end
  end

  def remove_child(child, edgelabel, varhash={})
    @children = @children.reject { |label_child| 
      label_child.first == edgelabel and
	label_child.last == child
    }

    # and vice versa: remove self as parent from child
    unless varhash["pointer_insteadof_edge"]
      if child.parents_with_edgelabel().include? [edgelabel, self]
        child.remove_parent(self, edgelabel)
      end
    end
  end

  def change_child_label(child, oldlabel, newlabel, varhash={})
    if @children.include? [oldlabel, child]
      remove_child(child,oldlabel, varhash)
      add_child(child, newlabel, varhash)
    end
  end

  def remove_all_children(varhash={})
    each_child_with_edgelabel { |label, child|
      remove_child(child, label, varhash)
    }
  end

  def set_children(list, varhash={})
    #### CAUTION: set_children must be called with an "internal format" list of parents:
    ####          instead of using [node, edgelabel], use [edgelabel, node]
    remove_all_children(varhash)

    @children = list
  end

  def outdeg()
    return @children.length()
  end

  def yield_nodes()
    arr = Array.new
    if outdeg() == 0
      arr << self
    end
    each_child { |c| 
      if c.outdeg() == 0
	arr << c
      else
	arr.concat c.yield_nodes
      end
    }
    return arr
  end

  def descendants
    return descendants_noduplicates([], [])
  end

  def descendants_by_edgelabels(labels)
    return descendants_noduplicates([], labels)
  end

  protected

  def descendants_noduplicates(nodes, labels)
    each_child_with_edgelabel() { |l_c|
      if labels.empty? or labels.include? l_c[0]
	unless nodes.include? l_c[1]
	  nodes = l_c[1].descendants_noduplicates(nodes << l_c[1], labels)
	end
      end
    }
    return nodes
  end
  
  def ancestors_noduplicates(nodes, labels)
    each_parent_with_edgelabel() { |l_p|
      if labels.empty? or labels.include? l_p[0]
	unless nodes.include? l_p[1]
	  nodes = l_p[1].ancestors_noduplicates(nodes << l_p[1], labels)
	end
      end
    }
    return nodes
  end

  #### CAUTION: set_parents must be called with an "internal format" list of parents:
  ####          instead of using [node, edgelabel], use [edgelabel, node]

  def set_parents(list, varhash={})
    each_parent_with_edgelabel { |label, parent|
      remove_parent(parent, label, varhash)
    }

    list.each { |label, parent|
      add_parent(label, parent)
    }
  end
end
