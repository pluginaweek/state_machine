require File.dirname(__FILE__) + '/../test_helper'

class PluginAWeek::Has::States::StateTransition
  attr_reader :guards
  public :guards
end

class StateTransitionTest < Test::Unit::TestCase
  fixtures :states
  attr_accessor :state
  
  def setup
    @callbacks = []
  end
  
  def callback(method)
    @callbacks << method
  end
  
  def test_should_store_from_state
    transition = create_transition
    assert_equal states(:switch_off), transition.from_state
  end
  
  def test_should_store_to_state
    transition = create_transition
    assert_equal states(:switch_on), transition.to_state
  end
  
  def test_should_perform_with_guard_check
    transition = create_transition(:if => :return_true)
    assert transition.can_perform_on?(self)
  end
  
  def test_should_perform_with_guard_array_with_single_check
    transition = create_transition(:if => [:return_true])
    assert transition.can_perform_on?(self)
  end
  
  def test_should_perform_with_guard_array_with_multiple_checks
    transition = create_transition(:if => [:return_true, :return_true])
    assert transition.can_perform_on?(self)
  end
  
  def test_should_perform_with_no_guards
    transition = create_transition
    assert transition.can_perform_on?(self)
  end
  
  def test_should_not_perform_if_all_guards_are_not_successful
    transition = create_transition(:if => [:return_true, :return_false])
    assert !transition.can_perform_on?(self)
  end
  
  def test_should_use_parameters_when_checking_guards
    transition = create_transition(:if => :return_param)
    assert transition.can_perform_on?(self, true)
  end
  
  def should_raise_exception_if_invalid_option_is_given
    assert_raise(ArgumentError) {create_transition(:invalid_key => true)}
  end
  
  def test_should_change_state_when_performed
    transition = create_transition
    transition.perform(self)
    
    assert_equal states(:switch_on), @state
  end
  
  def test_should_not_change_state_when_not_performed
    transition = create_transition(:if => :return_false)
    transition.perform(self)
    
    assert_nil @state
  end
  
  def test_should_invoke_callbacks_when_performed
    transition = create_transition
    transition.perform(self)
    
    assert_equal %w(before_exit_off before_enter_on after_exit_off after_enter_on), @callbacks
  end
  
  def test_should_not_invoke_callbacks_when_not_performed
    transition = create_transition(:if => :return_false)
    transition.perform(self)
    
    assert_equal [], @callbacks
  end
  
  def test_should_not_invoke_callbacks_when_looping_back_to_same_state
    transition = PluginAWeek::Has::States::StateTransition.new(states(:switch_on), states(:switch_on), {})
    transition.perform(self)
    
    assert_equal [], @callbacks
  end
  
  def test_different_transitions_should_not_be_equal
    transition = PluginAWeek::Has::States::StateTransition.new(states(:switch_off), states(:switch_on), {})
    different_transition = PluginAWeek::Has::States::StateTransition.new(states(:switch_on), states(:switch_off), {})
    
    assert transition != different_transition
  end
  
  def test_same_transitions_should_be_equal
    transition = PluginAWeek::Has::States::StateTransition.new(states(:switch_off), states(:switch_on), {})
    same_transition = PluginAWeek::Has::States::StateTransition.new(states(:switch_off), states(:switch_on), {})
    
    assert transition == same_transition
  end
  
  private
  def create_transition(options = {})
    PluginAWeek::Has::States::StateTransition.new(states(:switch_off), states(:switch_on), options)
  end
  
  def return_true
    true
  end
  
  def return_false
    false
  end
  
  def return_param(param)
    param
  end
end