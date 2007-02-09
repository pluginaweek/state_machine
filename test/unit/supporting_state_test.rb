require File.dirname(__FILE__) + '/../test_helper'

class PluginAWeek::Acts::StateMachine::Support::State
  attr_reader :options
end

class SupportingStateTest < Test::Unit::TestCase
  const_set('SupportingState', PluginAWeek::Acts::StateMachine::Support::State)
  
  cattr_accessor :use_state_deadlines
  
  def setup
    @record = states(:switch_on)
    @called_before_enter = false
    @called_after_enter = false
    @called_before_exit = false
    @called_after_exit = false
    @deadline_set = false
    
    @param_one = nil
    @param_two = nil
    
    self.class.use_state_deadlines = false
  end
  
  def test_invalid_key
    options = {:invalid_key => true}
    assert_raise(ArgumentError) {SupportingState.new(@record, options)}
  end
  
  def test_valid_key_as_string
    options = {:before_enter => :foo}
    assert_nothing_raised {SupportingState.new(@record, options)}
  end
  
  def test_default_deadline_passed_event
    state = SupportingState.new(@record, {})
    
    assert_equal :on, state.name
    assert_equal 'on_deadline_passed', state.options[:deadline_passed_event]
    assert_equal 'on_deadline_passed!', state.deadline_passed_event
  end
  
  def test_custom_deadline_passed_event
    options = {:deadline_passed_event => 'on_passed'}
    state = SupportingState.new(@record, options)
    
    assert_equal 'on_passed', state.options[:deadline_passed_event]
    assert_equal 'on_passed!', state.deadline_passed_event
  end
  
  def test_before_enter
    options = {:before_enter => :before_enter_action}
    state = SupportingState.new(@record, options)
    state.before_enter(self)
    
    assert @called_before_enter
    assert !@deadline_set
  end
  
  def test_after_enter_without_state_deadlines
    options = {:after_enter => :after_enter_action}
    state = SupportingState.new(@record, options)
    state.after_enter(self)
    
    assert @called_after_enter
    assert !@deadline_set
  end
  
  def test_after_enter_with_state_deadlines
    self.class.use_state_deadlines = true
    
    options = {:after_enter => :after_enter_action}
    state = SupportingState.new(@record, options)
    state.after_enter(self)
    
    assert @called_after_enter
    assert @deadline_set
  end
  
  def test_before_exit
    options = {:before_exit => :before_exit_action}
    state = SupportingState.new(@record, options)
    state.before_exit(self)
    
    assert @called_before_exit
    assert !@deadline_set
  end
  
  def test_after_exit
    options = {:after_exit => :after_exit_action}
    state = SupportingState.new(@record, options)
    state.after_exit(self)
    
    assert @called_after_exit
    assert !@deadline_set
  end
  
  def test_after_exit_with_parameters
    options = {:after_exit => :action_with_parameters}
    state = SupportingState.new(@record, options)
    state.after_exit(self, 1, 2)
    
    assert !@deadline_set
    assert_equal 1, @param_one
    assert_equal 2, @param_two
  end
  
  def test_name
    state = SupportingState.new(@record, {})
    assert_equal :on, state.name
  end
  
  def test_id
    state = SupportingState.new(@record, {})
    assert_equal @record.id, state.id
  end
  
  def set_on_deadline
    @deadline_set = true
  end
  
  private
  def before_enter_action
    @called_before_enter = true
  end
  
  def after_enter_action
    @called_after_enter = true
  end
  
  def before_exit_action
    @called_before_exit = true
  end
  
  def after_exit_action
    @called_after_exit = true
  end
  
  def action_with_parameters(param_one, param_two)
    @param_one = param_one
    @param_two = param_two
  end
end