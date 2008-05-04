require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransitionTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, 'off', 'on')
  end
  
  def test_should_have_a_from_state
    assert_equal 'off', @transition.from_state
  end
  
  def test_should_have_a_to_state
    assert_equal 'on', @transition.to_state
  end
  
  def test_should_not_be_a_loopback
    assert !@transition.loopback?
  end
  
  def test_should_not_be_able_to_perform_if_record_state_is_not_from_state
    record = new_switch(:state => 'on')
    assert !@transition.can_perform_on?(record)
  end
  
  def test_should_be_able_to_perform_if_record_state_is_from_state
    record = new_switch(:state => 'off')
    assert @transition.can_perform_on?(record)
  end
end

class TransitionWithoutFromStateTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, nil, 'on')
  end
  
  def test_should_not_have_a_from_state
    assert_nil @transition.from_state
  end
  
  def test_should_be_able_to_perform_on_all_states
    record = new_switch(:state => 'off')
    assert @transition.can_perform_on?(record)
    
    record = new_switch(:state => 'on')
    assert @transition.can_perform_on?(record)
  end
end

class TransitionWithLoopbackTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, 'on', 'on')
  end
  
  def test_should_have_a_from_state
    assert_equal 'on', @transition.from_state
  end
  
  def test_should_have_a_to_state
    assert_equal 'on', @transition.to_state
  end
  
  def test_should_be_a_loopback
    assert @transition.loopback?
  end
  
  def test_should_be_able_to_perform_if_record_is_in_from_state
    record = new_switch(:state => 'on')
    assert @transition.can_perform_on?(record)
  end
end

class TransitionAfterBeingPerformedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, 'off', 'on')
    
    @record = create_switch(:state => 'off')
    @transition.perform(@record)
    @record.reload
  end
  
  def test_should_update_the_state_to_the_to_state
    assert_equal 'on', @record.state
  end
  
  def test_should_no_longer_be_able_to_perform_on_the_record
    assert !@transition.can_perform_on?(@record)
  end
end

class TransitionWithLoopbackAfterBeingPerformedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, 'on', 'on')
    
    @record = create_switch(:state => 'on')
    @transition.perform(@record)
    @record.reload
  end
  
  def test_should_not_update_the_attribute
    assert_equal 'on', @record.state
  end
  
  def test_should_still_be_able_to_perform_on_the_record
    assert @transition.can_perform_on?(@record)
  end
end

class TransitionWithCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, 'off', 'on')
    @record = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_exit_state_off, :before_enter_state_on, :after_exit_state_off, :after_enter_state_on
  end
  
  def test_should_not_perform_if_before_exit_callback_fails
    Switch.before_exit_state_off Proc.new {|record| false}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal %w(), @record.callbacks
  end
  
  def test_should_not_perform_if_before_enter_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| false}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal %w(before_exit), @record.callbacks
  end
  
  def test_should_not_perform_if_after_exit_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| false}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal %w(before_exit before_enter), @record.callbacks
  end
  
  def test_should_not_perform_if_after_enter_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| false}
    
    assert !@transition.perform(@record)
    assert_equal %w(before_exit before_enter after_exit), @record.callbacks
  end
  
  def test_should_perform_if_all_callbacks_are_successful
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert @transition.perform(@record)
    assert_equal %w(before_exit before_enter after_exit after_enter), @record.callbacks
  end
  
  def teardown
    Switch.class_eval do
      @before_exit_state_off_callbacks = nil
      @before_enter_state_on_callbacks = nil
      @after_exit_state_off_callbacks = nil
      @after_enter_state_on_callbacks = nil
    end
  end
end

class TransitionWithoutFromStateAndCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, nil, 'on')
    @record = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_exit_state_off, :before_enter_state_on, :after_exit_state_off, :after_enter_state_on
  end
  
  def test_should_not_perform_if_before_exit_callback_fails
    Switch.before_exit_state_off Proc.new {|record| false}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal %w(), @record.callbacks
  end
  
  def test_should_not_perform_if_before_enter_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| false}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal %w(before_exit), @record.callbacks
  end
  
  def test_should_not_perform_if_after_exit_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| false}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal %w(before_exit before_enter), @record.callbacks
  end
  
  def test_should_not_perform_if_after_enter_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| false}
    
    assert !@transition.perform(@record)
    assert_equal %w(before_exit before_enter after_exit), @record.callbacks
  end
  
  def test_should_perform_if_all_callbacks_are_successful
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert @transition.perform(@record)
    assert_equal %w(before_exit before_enter after_exit after_enter), @record.callbacks
  end
  
  def teardown
    Switch.class_eval do
      @before_exit_state_off_callbacks = nil
      @before_enter_state_on_callbacks = nil
      @after_exit_state_off_callbacks = nil
      @after_enter_state_on_callbacks = nil
    end
  end
end

class TransitionWithLoopbackAndCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, 'on', 'on')
    @record = create_switch(:state => 'on')
    
    Switch.define_callbacks :before_exit_state_off, :before_enter_state_on, :after_exit_state_off, :after_enter_state_on
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert @transition.perform(@record)
  end
  
  def test_should_not_run_before_exit_callbacks
    assert !@record.callbacks.include?('before_exit')
  end
  
  def test_should_not_run_before_enter_callbacks
    assert !@record.callbacks.include?('before_enter')
  end
  
  def test_should_not_run_after_exit_callbacks
    assert !@record.callbacks.include?('after_exit')
  end
  
  def test_should_not_run_after_enter_callbacks
    assert !@record.callbacks.include?('after_enter')
  end
  
  def teardown
    Switch.class_eval do
      @before_exit_state_off_callbacks = nil
      @before_enter_state_on_callbacks = nil
      @after_exit_state_off_callbacks = nil
      @after_enter_state_on_callbacks = nil
    end
  end
end
