class Switch < ActiveRecord::Base
  cattr_accessor :active_states
  cattr_accessor :record_state_changes
  attr_accessor :state
  attr_reader :callbacks, :state_id, :recorded_event, :recorded_from_state, :recorded_to_state
  
  def initialize
    @callbacks = []
  end
  
  def before_turn_on
    @callbacks << 'before_turn_on'
  end
  
  def after_turn_on
    @callbacks << 'after_turn_on'
  end
  
  def turn_key
    @callbacks << 'turn_key'
  end
  
  def remove_key
    @callbacks << 'remove_key'
  end
  
  def return_false
    false
  end
  
  def return_true
    true
  end
  
  def return_param(param)
    param
  end
  
  def callback(method)
    @callbacks << method
    super
  end
  
  def update_attributes!(attrs)
    @state_id = attrs[:state_id]
  end
  
  private
  def record_state_change(event, from_state, to_state)
    @recorded_event = event.record if event
    @recorded_from_state = from_state.record if from_state
    @recorded_to_state = to_state.record if to_state
  end
end
