require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class EventTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {PluginAWeek::StateMachine::Event.new(@machine, 'turn_on', :invalid => true)}
  end
end

class EventByDefaultTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    
    @object = @klass.new
  end
  
  def test_should_have_a_machine
    assert_equal @machine, @event.machine
  end
  
  def test_should_have_a_name
    assert_equal 'turn_on', @event.name
  end
  
  def test_should_not_have_any_guards
    assert @event.guards.empty?
  end
  
  def test_should_have_no_known_states
    assert @event.known_states.empty?
  end
  
  def test_should_not_be_able_to_fire
    assert !@event.can_fire?(@object)
  end
  
  def test_should_not_have_a_next_transition
    assert_nil @event.next_transition(@object)
  end
  
  def test_should_define_an_event_predicate_on_the_owner_class
    assert @object.respond_to?(:can_turn_on?)
  end
  
  def test_should_define_an_event_transition_accessor_on_the_owner_class
    assert @object.respond_to?(:next_turn_on_transition)
  end
  
  def test_should_define_an_event_action_on_the_owner_class
    assert @object.respond_to?(:turn_on)
  end
  
  def test_should_define_an_event_bang_action_on_the_owner_class
    assert @object.respond_to?(:turn_on!)
  end
end

class EventTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {@event.transition(:invalid => true)}
  end
  
  def test_should_not_raise_exception_if_to_option_not_specified
    assert_nothing_raised {@event.transition(:from => 'off')}
  end
  
  def test_should_not_raise_exception_if_from_option_not_specified
    assert_nothing_raised {@event.transition(:to => 'on')}
  end
  
  def test_should_not_allow_on_option
    assert_raise(ArgumentError) {@event.transition(:on => 'turn_on')}
  end
  
  def test_should_not_allow_except_to_option
    assert_raise(ArgumentError) {@event.transition(:except_to => 'off')}
  end
  
  def test_should_not_allow_except_on_option
    assert_raise(ArgumentError) {@event.transition(:except_on => 'turn_on')}
  end
  
  def test_should_allow_transitioning_without_a_from_state
    assert @event.transition(:to => 'on')
  end
  
  def test_should_allow_transitioning_without_a_to_state
    assert @event.transition(:from => 'off')
  end
  
  def test_should_allow_transitioning_from_a_single_state
    assert @event.transition(:to => 'on', :from => 'off')
  end
  
  def test_should_allow_transitioning_from_multiple_states
    assert @event.transition(:to => 'on', :from => %w(off on))
  end
  
  def test_should_have_transitions
    guard = @event.transition(:to => 'on')
    assert_equal [guard], @event.guards
  end
end

class EventAfterBeingCopiedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.known_states # Call so that it's cached
    @copied_event = @event.dup
  end
  
  def test_should_not_have_the_same_collection_of_guards
    assert_not_same @event.guards, @copied_event.guards
  end
  
  def test_should_not_have_the_same_collection_of_known_states
    assert_not_same @event.known_states, @copied_event.known_states
  end
end

class EventWithoutTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @object = @klass.new
  end
  
  def test_should_not_be_able_to_fire
    assert !@event.can_fire?(@object)
  end
  
  def test_should_not_have_a_next_transition
    assert_nil @event.next_transition(@object)
  end
  
  def test_should_not_fire
    assert !@event.fire(@object)
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_nil @object.state
  end
end

class EventWithTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition(:to => 'on', :from => 'off')
    @event.transition(:to => 'on', :except_from => 'maybe')
  end
  
  def test_should_include_all_transition_states_in_known_states
    assert_equal %w(maybe off on), @event.known_states.sort
  end
end

class EventWithoutMatchingTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition(:to => 'on', :from => 'off')
    
    @object = @klass.new
    @object.state = 'on'
  end
  
  def test_should_not_be_able_to_fire
    assert !@event.can_fire?(@object)
  end
  
  def test_should_not_have_a_next_transition
    assert_nil @event.next_transition(@object)
  end
  
  def test_should_not_fire
    assert !@event.fire(@object)
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_equal 'on', @object.state
  end
end

class EventWithMatchingDisabledTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition(:to => 'on', :from => 'off', :if => lambda {false})
    
    @object = @klass.new
    @object.state = 'off'
  end
  
  def test_should_not_be_able_to_fire
    assert !@event.can_fire?(@object)
  end
  
  def test_should_not_have_a_next_transition
    assert_nil @event.next_transition(@object)
  end
  
  def test_should_not_fire
    assert !@event.fire(@object)
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_equal 'off', @object.state
  end
end

class EventWithMatchingEnabledTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition(:to => 'on', :from => 'off')
    
    @object = @klass.new
    @object.state = 'off'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_next_transition
    transition = @event.next_transition(@object)
    assert_not_nil transition
    assert_equal 'off', transition.from
    assert_equal 'on', transition.to
    assert_equal 'turn_on', transition.event
  end
  
  def test_should_fire
    assert @event.fire(@object)
  end
  
  def test_should_change_the_current_state
    @event.fire(@object)
    assert_equal 'on', @object.state
  end
end

class EventWithTransitionWithoutToStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_off')
    @event.transition(:from => 'off')
    
    @object = @klass.new
    @object.state = 'off'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_next_transition
    transition = @event.next_transition(@object)
    assert_not_nil transition
    assert_equal 'off', transition.from
    assert_equal 'off', transition.to
    assert_equal 'turn_off', transition.event
  end
  
  def test_should_fire
    assert @event.fire(@object)
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_equal 'off', @object.state
  end
end

class EventWithTransitionWithDynamicToStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition(:to => lambda {'on'}, :from => 'off')
    
    @object = @klass.new
    @object.state = 'off'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_next_transition
    transition = @event.next_transition(@object)
    assert_not_nil transition
    assert_equal 'off', transition.from
    assert_equal 'on', transition.to
    assert_equal 'turn_on', transition.event
  end
  
  def test_should_fire
    assert @event.fire(@object)
  end
  
  def test_should_change_the_current_state
    @event.fire(@object)
    assert_equal 'on', @object.state
  end
end

class EventWithMultipleTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition(:to => 'on', :from => 'on')
    @event.transition(:to => 'on', :from => 'off') # This one should get used
    
    @object = @klass.new
    @object.state = 'off'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_next_transition
    transition = @event.next_transition(@object)
    assert_not_nil transition
    assert_equal 'off', transition.from
    assert_equal 'on', transition.to
    assert_equal 'turn_on', transition.event
  end
  
  def test_should_fire
    assert @event.fire(@object)
  end
  
  def test_should_change_the_current_state
    @event.fire(@object)
    assert_equal 'on', @object.state
  end
end
