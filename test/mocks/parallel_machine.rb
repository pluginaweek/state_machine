class ParallelMachine
  attr_accessor :turn_on_called,
                :turn_on_now_called
  
  def initialize(succeed)
    @succeed = succeed
  end
  
  def turn_on!
    @turn_on_called = true
    @succeed
  end
  
  def turn_on_now!
    @turn_on_now_called = true
    @succeed
  end
end