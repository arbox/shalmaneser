################
# Given an enumerable, distribute its items into two bins (arrays)
# depending on whether the block returns true
module EnumerableDistribute
  def distribute(&block)
    retv1 = []
    retv2 = []
    each do |x|
      if block.call(x)
        retv1 << x
      else
        retv2 << x
      end
    end

    [retv1, retv2]
  end
end
