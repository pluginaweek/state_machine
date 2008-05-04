class Switch < ActiveRecord::Base
  # Tracks the callbacks that were invoked
  attr_reader :callbacks
  
  # Dynamic sets the initial state
  attr_accessor :initial_state
  
  def initialize(attributes = nil)
    @callbacks = []
    super
  end
end
