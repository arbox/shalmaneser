###
# extend Array class by subsumption
module Subsumed
  # @note This method is used by [RosyConfusability]
  def subsumed_by?(array2)
    temp = array2.clone

    self.each { |el|
      found = false
      temp.each_index { |ix|
        if el == temp[ix]
          temp.delete_at(ix)
          found = true
          break
        end
      }
      unless found
        return false
      end
    }

    return true
  end
end
