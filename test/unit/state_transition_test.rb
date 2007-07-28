require File.dirname(__FILE__) + '/../test_helper'

class PluginAWeek::Has::States::StateTransition
  attr_reader :guards
  public :guards
end

class StateTransitionTest < Test::Unit::TestCase
  def test_should_store_from_state
    transition = create_transition
    assert_equal states(:switch_off), transition.from_state.record
  end
  
  def test_should_store_to_state
    transition = create_transition
    assert_equal states(:switch_on), transition.to_state.record
  end
  
  def test_should_not_be_loopback_if_from_and_to_state_are_different
    transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off), active_state(:switch_on), {})
    assert !transition.loopback?
  end
  
  def test_should_be_loopback_if_from_and_to_state_are_same
    transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off), active_state(:switch_off), {})
    assert transition.loopback?
  end
  
  def test_should_perform_with_guard_check
    transition = create_transition(:if => :return_true)
    assert transition.can_perform_on?(Switch.new)
  end
  
  def test_should_perform_with_guard_array_with_single_check
    transition = create_transition(:if => [:return_true])
    assert transition.can_perform_on?(Switch.new)
  end
  
  def test_should_perform_with_guard_array_with_multiple_checks
    transition = create_transition(:if => [:return_true, :return_true])
    assert transition.can_perform_on?(Switch.new)
  end
  
  def test_should_perform_with_no_guards
    transition = create_transition
    assert transition.can_perform_on?(self)
  end
  
  def test_should_not_perform_if_all_guards_are_not_successful
    transition = create_transition(:if => [:return_true, :return_false])
    assert !transition.can_perform_on?(Switch.new)
  end
  
  def test_should_use_parameters_when_checking_guards
    transition = create_transition(:if => :return_param)
    assert transition.can_perform_on?(Switch.new, true)
  end
  
  def test_should_not_perform_if_before_exit_callback_returns_false
    transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off, :before_exit => :return_false), active_state(:switch_on), {})
    assert !transition.perform(active_event(:switch_turn_on), Switch.new)
  end
  
  def test_should_not_perform_if_before_enter_callback_returns_false
    transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off), active_state(:switch_on, :before_enter => :return_false), {})
    assert !transition.perform(active_event(:switch_turn_on), Switch.new)
  end
  
  def test_should_not_perform_if_after_exit_callback_returns_false
    transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off, :after_exit => :return_false), active_state(:switch_on), {})
    assert !transition.perform(active_event(:switch_turn_on), Switch.new)
  end
  
  def test_should_not_perform_if_after_enter_callback_returns_false
    transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off), active_state(:switch_on, :after_enter => :return_false), {})
    assert !transition.perform(active_event(:switch_turn_on), Switch.new)
  end
  
  def should_raise_exception_if_invalid_option_is_given
    assert_raise(ArgumentError) {create_transition(:invalid_key => true)}
  end
  
  def test_should_change_state_when_performed
    switch = Switch.new
    transition = create_transition
    transition.perform(active_event(:switch_turn_on), switch)
    
    assert_equal states(:switch_on).id, switch.state_id
  end
  
  def test_should_not_change_state_when_not_performed
    switch = Switch.new
    transition = create_transition(:if => :return_false)
    transition.perform(active_event(:switch_turn_on), switch)
    
    assert_nil switch.state
  end
  
  def test_should_invoke_callbacks_when_performed
    switch = Switch.new
    transition = create_transition
    transition.perform(active_event(:switch_turn_on), switch)
    
    assert_equal %w(before_exit_off before_enter_on after_exit_off after_enter_on), switch.callbacks
  end
  
  def test_should_not_invoke_callbacks_when_not_performed
    switch = Switch.new
    transition = create_transition(:if => :return_false)
    transition.perform(active_event(:switch_turn_on), switch)
    
    assert_equal [], switch.callbacks
  end
  
  def test_should_not_invoke_callbacks_when_looping_back_to_same_state
    switch = Switch.new
    transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_on), active_state(:switch_on), {})
    transition.perform(active_event(:switch_turn_on), switch)
    
    assert_equal [], switch.callbacks
  end
  
  def test_different_transitions_should_not_be_equal
    transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off), active_state(:switch_on), {})
    different_transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_on), active_state(:switch_off), {})
    
    assert transition != different_transition
  end
  
  def test_same_transitions_should_be_equal
    transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off), active_state(:switch_on), {})
    same_transition = PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off), active_state(:switch_on), {})
    
    assert transition == same_transition
  end
  
  private
  def create_transition(options = {})
    PluginAWeek::Has::States::StateTransition.new(active_state(:switch_off), active_state(:switch_on), options)
  end
  
  def active_event(name, options = {})
    PluginAWeek::Has::States::ActiveEvent.new(Switch, events(name), options)
  end
  
  def active_state(name, options = {})
    PluginAWeek::Has::States::ActiveState.new(Switch, states(name), options)
  end
end