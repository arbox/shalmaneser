################
module EnumerableBool
  ###
  # And_(x \in X) block(x)
  def big_and(&block)
    each do |x|
      unless block.call(x)
        return false
      end
    end

    true
  end

  ###
  # Sum_(x \in X) block(x)
  def big_sum(init = 0, &block)
    sum = init
    block = proc { |x| x } unless block_given?
    each { |x| sum += block.call(x) }

    sum
  end
end
