require File.dirname(__FILE__) + '/../test_helper'

class ActiveStateTest < Test::Unit::TestCase
  def setup
    Switch.record_state_changes = true
    
    @original_instance_methods = Switch.instance_methods
    @state = PluginAWeek::Has::States::ActiveState.new(Switch, states(:switch_on))
  end
  
  def test_should_raise_exception_if_invalid_option_used_on_create
    assert_raise(ArgumentError) {PluginAWeek::Has::States::ActiveState.new(Switch, State.new, :invalid_option => true)}
  end
  
  def test_should_set_owner_class_to_initialized_class
    assert_equal Switch, @state.owner_class
  end
  
  def test_should_allow_owner_class_to_be_modified
    @state.owner_class = self.class
    assert_equal self.class, @state.owner_class
  end
  
  def test_should_not_cache_owner_class
    owner_class = @state.owner_class
    @state.owner_class = self.class
    assert_not_equal owner_class, @state.owner_class
    assert_equal self.class, @state.owner_class
  end
  
  def test_should_create_predicate_methods
    assert Switch.instance_methods.include?('on?')
  end
  
  def test_should_create_state_change_accessor_for_each_state_if_recording_changes
    assert Switch.instance_methods.include?('on_at')
  end
  
  def test_should_not_create_state_change_accessor_for_each_state_if_not_recording_changes
    Switch.record_state_changes = false
    
    PluginAWeek::Has::States::ActiveState.new(Switch, states(:switch_off))
    
    assert !Switch.instance_methods.include?('off_at')
  end
  
  def test_should_create_callbacks
    [:before_enter, :after_enter, :before_exit, :after_exit].each do |callback|
      assert Switch.singleton_methods.include?("#{callback}_on")
    end
  end
  
  def test_should_create_state_finders_for_each_active_state
    assert Switch::StateExtension.instance_methods.include?('on')
  end
  
  def test_should_create_state_counters_for_each_active_state
    assert Switch::StateExtension.instance_methods.include?('on_count')
  end
  
  private
  def create_transition(from_state_name, to_state_name)
    PluginAWeek::Has::States::StateTransition.new(Switch.active_states[from_state_name], Switch.active_states[to_state_name], {})
  end
end