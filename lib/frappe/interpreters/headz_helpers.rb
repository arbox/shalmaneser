class HeadzHelpers
  @Verbose = true

  # Conjunction

  def get_conjuncts(node)
    get_dtrs(node, 'CJ')
  end

  # flatten
  def descend(current, flat)
    if current.nil?
      return flat
    end

    if current.key?("conj")
      tmp = current.delete("conj")
      flat.push current
      tmp.each { |item| descend(item, flat) }
    else
      flat.push current
    end
  end

  # Zugriff

  def get_dtr(node,label)
    if (dtrs = node.children_by_edgelabels([label]))
      dtrs.first
    else
      if @Verbose then $stderr.puts " SelectHeadDtr: no #{label} dtr for #{node}" end
      nil
    end
  end

  def get_dtrs(node,label)
    if ! dtrs = node.children_by_edgelabels([label])
      if @Verbose then $stderr.puts " SelectHeadDtr: no #{label} dtr for #{node}" end
    else
      dtrs
    end
  end

  def get_rightmost_dtr(node,label)
    children = node.children_by_edgelabels([label])
    if re = children.last then re
    else
      if @Verbose then $stderr.puts " SelectHeadDtr: no #{label} dtrs for #{node}" end
      nil
    end
  end
end # Class HeadzHelpers
