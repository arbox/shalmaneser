module ConvexComp

  def convex_complemented(node_set)
    terminals = terminals_sorted

    yield_nodes = node_set.map { |node| node.yield_nodes_ordered }.flatten

    leftmost =  yield_nodes.map { |t| terminals.index(t) }.min
    rightmost = yield_nodes.map { |t| terminals.index(t) }.max
    if leftmost.nil? || rightmost.nil?
      STDERR.puts "Warning: could not complement projected node set #{yield_nodes.map {|t| t.id}}; terminals not found in sorted set of sentence terminals!?"
      return node_set
    else
      STDERR.puts "Replacing " + yield_nodes.join(" ")
      new_node_set = terminals[leftmost..rightmost]
      STDERR.puts "By        " + new_node_set.join(" ")
      return max_constituents_for_nodes(new_node_set)
    end
  end
end
