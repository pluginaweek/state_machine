require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class EventByDefaultTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @event = StateMachine::Event.new(@machine, :ignite)
    
    @object = @klass.new
  end
  
  def test_should_have_a_machine
    assert_equal @machine, @event.machine
  end
  
  def test_should_have_a_name
    assert_equal :ignite, @event.name
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
  
  def test_should_define_a_predicate
    assert @object.respond_to?(:can_ignite?)
  end
  
  def test_should_define_a_transition_accessor
    assert @object.respond_to?(:next_ignite_transition)
  end
  
  def test_should_define_an_action
    assert @object.respond_to?(:ignite)
  end
  
  def test_should_define_a_bang_action
    assert @object.respond_to?(:ignite!)
  end
end

class EventTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition :parked => :idling
  end
  
  def test_should_allow_changing_machine
    new_machine = StateMachine::Machine.new(Class.new)
    @event.machine = new_machine
    assert_equal new_machine, @event.machine
  end
  
  def test_should_provide_matcher_helpers_during_initialization
    matchers = []
    
    @event.instance_eval do
      matchers = [all, any, same]
    end
    
    assert_equal [StateMachine::AllMatcher.instance, StateMachine::AllMatcher.instance, StateMachine::LoopbackMatcher.instance], matchers
  end
  
  def test_should_use_pretty_inspect
    assert_match "#<StateMachine::Event name=:ignite transitions=[:parked => :idling]>", @event.inspect
  end
end

class EventWithNamespaceTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :namespace => 'car')
    @event = StateMachine::Event.new(@machine, :ignite)
    @object = @klass.new
  end
  
  def test_should_namespace_predicate
    assert @object.respond_to?(:can_ignite_car?)
  end
  
  def test_should_namespace_transition_accessor
    assert @object.respond_to?(:next_ignite_car_transition)
  end
  
  def test_should_namespace_action
    assert @object.respond_to?(:ignite_car)
  end
  
  def test_should_namespace_bang_action
    assert @object.respond_to?(:ignite_car!)
  end
end

class EventTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @event = StateMachine::Event.new(@machine, :ignite)
  end
  
  def test_should_not_raise_exception_if_implicit_option_specified
    assert_nothing_raised {@event.transition(:invalid => true)}
  end
  
  def test_should_not_allow_on_option
    exception = assert_raise(ArgumentError) {@event.transition(:on => :ignite)}
    assert_equal 'Invalid key(s): on', exception.message
  end
  
  def test_should_not_allow_except_to_option
    exception = assert_raise(ArgumentError) {@event.transition(:except_to => :parked)}
    assert_equal 'Invalid key(s): except_to', exception.message
  end
  
  def test_should_not_allow_except_on_option
    exception = assert_raise(ArgumentError) {@event.transition(:except_on => :ignite)}
    assert_equal 'Invalid key(s): except_on', exception.message
  end
  
  def test_should_allow_transitioning_without_a_to_state
    assert_nothing_raised {@event.transition(:from => :parked)}
  end
  
  def test_should_allow_transitioning_without_a_from_state
    assert_nothing_raised {@event.transition(:to => :idling)}
  end
  
  def test_should_allow_except_from_option
    assert_nothing_raised {@event.transition(:except_from => :idling)}
  end
  
  def test_should_allow_transitioning_from_a_single_state
    assert @event.transition(:parked => :idling)
  end
  
  def test_should_allow_transitioning_from_multiple_states
    assert @event.transition([:parked, :idling] => :idling)
  end
  
  def test_should_have_transitions
    guard = @event.transition(:to => :idling)
    assert_equal [guard], @event.guards
  end
end

class EventAfterBeingCopiedTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @event = StateMachine::Event.new(@machine, :ignite)
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
    @machine = StateMachine::Machine.new(@klass)
    @event = StateMachine::Event.new(@machine, :ignite)
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
  
  def test_should_raise_exception_on_fire!
    exception = assert_raise(StateMachine::InvalidTransition) { @event.fire!(@object) }
    assert_equal 'Cannot transition state via :ignite from nil', exception.message
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_nil @object.state
  end
end

class EventWithTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:parked => :idling)
    @event.transition(:first_gear => :idling)
  end
  
  def test_should_include_all_transition_states_in_known_states
    assert_equal [:parked, :idling, :first_gear], @event.known_states
  end
  
  def test_should_include_new_transition_states_after_calling_known_states
    @event.known_states
    @event.transition(:stalled => :idling)
    
    assert_equal [:parked, :idling, :first_gear, :stalled], @event.known_states
  end
  
  def test_should_use_pretty_inspect
    assert_match "#<StateMachine::Event name=:ignite transitions=[:parked => :idling, :first_gear => :idling]>", @event.inspect
  end
end

class EventWithoutMatchingTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:parked => :idling)
    
    @object = @klass.new
    @object.state = 'idling'
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
  
  def test_should_raise_exception_on_fire!
    exception = assert_raise(StateMachine::InvalidTransition) { @event.fire!(@object) }
    assert_equal 'Cannot transition state via :ignite from :idling', exception.message
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_equal 'idling', @object.state
  end
end

class EventWithMatchingDisabledTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:parked => :idling, :if => lambda {false})
    
    @object = @klass.new
    @object.state = 'parked'
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
    assert_equal 'parked', @object.state
  end
end

class EventWithMatchingEnabledTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:parked => :idling)
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_next_transition
    transition = @event.next_transition(@object)
    assert_not_nil transition
    assert_equal 'parked', transition.from
    assert_equal 'idling', transition.to
    assert_equal :ignite, transition.event
  end
  
  def test_should_fire
    assert @event.fire(@object)
  end
  
  def test_should_change_the_current_state
    @event.fire(@object)
    assert_equal 'idling', @object.state
  end
end

class EventWithTransitionWithoutToStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked
    
    @event = StateMachine::Event.new(@machine, :park)
    @event.transition(:from => :parked)
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_next_transition
    transition = @event.next_transition(@object)
    assert_not_nil transition
    assert_equal 'parked', transition.from
    assert_equal 'parked', transition.to
    assert_equal :park, transition.event
  end
  
  def test_should_fire
    assert @event.fire(@object)
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_equal 'parked', @object.state
  end
end

class EventWithTransitionWithNilToStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state nil
    @machine.state :idling
    
    @event = StateMachine::Event.new(@machine, :park)
    @event.transition(:idling => nil)
    
    @object = @klass.new
    @object.state = 'idling'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_next_transition
    transition = @event.next_transition(@object)
    assert_not_nil transition
    assert_equal 'idling', transition.from
    assert_equal nil, transition.to
    assert_equal :park, transition.event
  end
  
  def test_should_fire
    assert @event.fire(@object)
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_equal nil, @object.state
  end
end

class EventWithMultipleTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:idling => :idling)
    @event.transition(:parked => :idling) # This one should get used
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_next_transition
    transition = @event.next_transition(@object)
    assert_not_nil transition
    assert_equal 'parked', transition.from
    assert_equal 'idling', transition.to
    assert_equal :ignite, transition.event
  end
  
  def test_should_fire
    assert @event.fire(@object)
  end
  
  def test_should_change_the_current_state
    @event.fire(@object)
    assert_equal 'idling', @object.state
  end
end

begin
  # Load library
  require 'rubygems'
  require 'graphviz'
  
  class EventDrawingTest < Test::Unit::TestCase
    def setup
      states = [:parked, :idling, :first_gear]
      
      @machine = StateMachine::Machine.new(Class.new, :initial => :parked)
      @machine.other_states(*states)
      
      graph = GraphViz.new('G')
      states.each {|state| graph.add_node(state.to_s)}
      
      @event = StateMachine::Event.new(@machine , :park)
      @event.transition :parked => :idling
      @event.transition :first_gear => :parked
      @event.transition :except_from => :parked, :to => :parked
      
      @edges = @event.draw(graph)
    end
    
    def test_should_generate_edges_for_each_transition
      assert_equal 4, @edges.size
    end
    
    def test_should_use_event_name_for_edge_label
      assert_equal 'park', @edges.first['label']
    end
  end
rescue LoadError
  $stderr.puts 'Skipping GraphViz StateMachine::Event tests. `gem install ruby-graphviz` and try again.'
end
