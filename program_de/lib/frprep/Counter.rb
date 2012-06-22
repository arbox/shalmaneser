# Counter class - provides unique ids with state

class Counter

  def get
    return @v
  end

  def next
    @v += 1
    return (@v-1)
  end    

  def initialize(init_value)
    @v = init_value
  end

end
