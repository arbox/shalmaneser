# Counter class - provides unique ids with state
class Counter
  def initialize(init_value)
    @v = init_value
  end

  def get
    @v
  end

  def next
    @v += 1
    @v - 1
  end
end
