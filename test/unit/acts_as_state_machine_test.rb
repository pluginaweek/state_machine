require File.dirname(__FILE__) + '/../test_helper'

DefaultMachine.class_eval do
  class_inheritable_reader :initial_state_name
end

class ActsAsStateMachineTest < Test::Unit::TestCase
#  fixtures :auto_shops
#  
  def setup
    @vehicle = Vehicle.new
    @car = Car.new
    @motorcycle = Motorcycle.new
    @auto_shop = AutoShop.new
  end
  
  def test_invalid_key
    options = {:invalid_key => true}
    assert_raise(ArgumentError) {Message.acts_as_state_machine(options)}
  end
  
  def test_no_initial_state
    assert_raise(PluginAWeek::Acts::StateMachine::NoInitialState) {Message.acts_as_state_machine({})}
  end
  
  def test_default_states
    expected = {}
    assert_equal expected, DefaultMachine.states
  end
  
  def test_default_initial_state_name
    assert_equal :dummy, DefaultMachine.initial_state_name
  end
  
  def test_default_transitions
    expected = {}
    assert_equal expected, DefaultMachine.transitions
  end
  
  def test_default_events
    expected = {}
    assert_equal expected, DefaultMachine.events
  end
  
  def test_default_use_state_deadlines
    assert !DefaultMachine.use_state_deadlines
  end
  
  def test_state_extension
    assert_not_nil Vehicle::StateExtension
  end
  
  def test_no_deadline_class
    assert !Switch.use_state_deadlines
    assert !Switch.const_defined?('StateDeadline')
  end
  
  def test_state_type
  end
  
  def test_state_changes_type
  end
  
  def test_state_deadlines_type
  end
end
