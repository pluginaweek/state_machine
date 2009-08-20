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
  
  def test_should_have_a_qualified_name
    assert_equal :ignite, @event.qualified_name
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
  
  def test_should_not_have_a_transition
    assert_nil @event.transition_for(@object)
  end
  
  def test_should_define_a_predicate
    assert @object.respond_to?(:can_ignite?)
  end
  
  def test_should_define_a_transition_accessor
    assert @object.respond_to?(:ignite_transition)
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

class EventWithConflictingHelpersTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def can_ignite?
        0
      end
      
      def ignite_transition
        0
      end
      
      def ignite
        0
      end
      
      def ignite!
        0
      end
    end
    @machine = StateMachine::Machine.new(@klass)
    @state = StateMachine::Event.new(@machine, :ignite)
    @object = @klass.new
  end
  
  def test_should_not_redefine_predicate
    assert_equal 0, @object.can_ignite?
  end
  
  def test_should_not_redefine_transition_accessor
    assert_equal 0, @object.ignite_transition
  end
  
  def test_should_not_redefine_action
    assert_equal 0, @object.ignite
  end
  
  def test_should_not_redefine_bang_action
    assert_equal 0, @object.ignite!
  end
  
  def test_should_allow_super_chaining
    @klass.class_eval do
      def can_ignite?
        super ? 1 : 0
      end
      
      def ignite_transition
        super ? 1 : 0
      end
      
      def ignite
        super ? 1 : 0
      end
      
      def ignite!
        begin
          super
          1
        rescue Exception => ex
          0
        end
      end
    end
    
    assert_equal 0, @object.can_ignite?
    assert_equal 0, @object.ignite_transition
    assert_equal 0, @object.ignite
    assert_equal 1, @object.ignite!
  end
end

class EventWithNamespaceTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :namespace => 'alarm')
    @event = StateMachine::Event.new(@machine, :enable)
    @object = @klass.new
  end
  
  def test_should_have_a_name
    assert_equal :enable, @event.name
  end
  
  def test_should_have_a_qualified_name
    assert_equal :enable_alarm, @event.qualified_name
  end
  
  def test_should_namespace_predicate
    assert @object.respond_to?(:can_enable_alarm?)
  end
  
  def test_should_namespace_transition_accessor
    assert @object.respond_to?(:enable_alarm_transition)
  end
  
  def test_should_namespace_action
    assert @object.respond_to?(:enable_alarm)
  end
  
  def test_should_namespace_bang_action
    assert @object.respond_to?(:enable_alarm!)
  end
end

class EventTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @event = StateMachine::Event.new(@machine, :ignite)
  end
  
  def test_should_not_raise_exception_if_implicit_option_specified
    assert_nothing_raised {@event.transition(:invalid => :valid)}
  end
  
  def test_should_not_allow_on_option
    exception = assert_raise(ArgumentError) {@event.transition(:on => :ignite)}
    assert_equal 'Invalid key(s): on', exception.message
  end
  
  def test_should_automatically_set_on_option
    guard = @event.transition(:to => :idling)
    assert_instance_of StateMachine::WhitelistMatcher, guard.event_requirement
    assert_equal [:ignite], guard.event_requirement.values
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
  
  def test_should_not_have_a_transition
    assert_nil @event.transition_for(@object)
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
  
  def test_should_not_have_a_transition
    assert_nil @event.transition_for(@object)
  end
  
  def test_should_not_fire
    assert !@event.fire(@object)
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_equal 'idling', @object.state
  end
end

class EventWithMatchingDisabledTransitionsTest < Test::Unit::TestCase
  def setup
    StateMachine::Integrations.const_set('Custom', Module.new do
      def invalidate(object, attribute, message, values = [])
        (object.errors ||= []) << generate_message(message, values)
      end
      
      def reset(object)
        object.errors = []
      end
    end)
    
    @klass = Class.new do
      attr_accessor :errors
    end
    
    @machine = StateMachine::Machine.new(@klass, :integration => :custom)
    @machine.state :parked, :idling
    
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:parked => :idling, :if => lambda {false})
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_not_be_able_to_fire
    assert !@event.can_fire?(@object)
  end
  
  def test_should_not_have_a_transition
    assert_nil @event.transition_for(@object)
  end
  
  def test_should_not_fire
    assert !@event.fire(@object)
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@object)
    assert_equal 'parked', @object.state
  end
  
  def test_should_invalidate_the_state
    @event.fire(@object)
    assert_equal ['cannot transition via "ignite"'], @object.errors
  end
  
  def test_should_reset_existing_error
    @object.errors = ['invalid']
    
    @event.fire(@object)
    assert_equal ['cannot transition via "ignite"'], @object.errors
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class EventWithMatchingEnabledTransitionsTest < Test::Unit::TestCase
  def setup
    StateMachine::Integrations.const_set('Custom', Module.new do
      def invalidate(object, attribute, message, values = [])
        (object.errors ||= []) << generate_message(message, values)
      end
      
      def reset(object)
        object.errors = []
      end
    end)
    
    @klass = Class.new do
      attr_accessor :errors
    end
    
    @machine = StateMachine::Machine.new(@klass, :integration => :custom)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:parked => :idling)
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_transition
    transition = @event.transition_for(@object)
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
  
  def test_should_reset_existing_error
    @object.errors = ['invalid']
    
    @event.fire(@object)
    assert_equal [], @object.errors
  end
  
  def test_should_not_invalidate_the_state
    @event.fire(@object)
    assert_equal [], @object.errors
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class EventWithTransitionWithoutToStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked
    @machine.event :park
    
    @event = StateMachine::Event.new(@machine, :park)
    @event.transition(:from => :parked)
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_transition
    transition = @event.transition_for(@object)
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
    @machine.state nil, :idling
    @machine.event :park
    
    @event = StateMachine::Event.new(@machine, :park)
    @event.transition(:idling => nil)
    
    @object = @klass.new
    @object.state = 'idling'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_transition
    transition = @event.transition_for(@object)
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
    @machine.event :ignite
    
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:idling => :idling)
    @event.transition(:parked => :idling) # This one should get used
    @event.transition(:parked => :parked)
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_be_able_to_fire
    assert @event.can_fire?(@object)
  end
  
  def test_should_have_a_transition
    transition = @event.transition_for(@object)
    assert_not_nil transition
    assert_equal 'parked', transition.from
    assert_equal 'idling', transition.to
    assert_equal :ignite, transition.event
  end
  
  def test_should_allow_specific_transition_selection_using_from
    transition = @event.transition_for(@object, :from => :idling)
    
    assert_not_nil transition
    assert_equal 'idling', transition.from
    assert_equal 'idling', transition.to
    assert_equal :ignite, transition.event
  end
  
  def test_should_allow_specific_transition_selection_using_to
    transition = @event.transition_for(@object, :from => :parked, :to => :parked)
    
    assert_not_nil transition
    assert_equal 'parked', transition.from
    assert_equal 'parked', transition.to
    assert_equal :ignite, transition.event
  end
  
  def test_should_allow_specific_transition_selection_using_on
    transition = @event.transition_for(@object, :on => :park)
    assert_nil transition
    
    transition = @event.transition_for(@object, :on => :ignite)
    assert_not_nil transition
  end
  
  def test_should_fire
    assert @event.fire(@object)
  end
  
  def test_should_change_the_current_state
    @event.fire(@object)
    assert_equal 'idling', @object.state
  end
end

class EventWithMachineActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    
    @machine.events << @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:parked => :idling)
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_run_action_on_fire
    @event.fire(@object)
    assert @object.saved
  end
  
  def test_should_not_run_action_if_configured_to_skip
    @event.fire(@object, false)
    assert !@object.saved
  end
end

class EventWithInvalidCurrentStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:parked => :idling)
    
    @object = @klass.new
    @object.state = 'invalid'
  end
  
  def test_should_raise_exception_when_checking_availability
    exception = assert_raise(ArgumentError) { @event.can_fire?(@object) }
    assert_equal '"invalid" is not a known state value', exception.message
  end
  
  def test_should_raise_exception_when_finding_transition
    exception = assert_raise(ArgumentError) { @event.transition_for(@object) }
    assert_equal '"invalid" is not a known state value', exception.message
  end
  
  def test_should_raise_exception_when_firing
    exception = assert_raise(ArgumentError) { @event.fire(@object) }
    assert_equal '"invalid" is not a known state value', exception.message
  end
end

class EventWithMarshallingTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
        true
      end
    end
    self.class.const_set('Example', @klass)
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    
    @machine.events << @event = StateMachine::Event.new(@machine, :ignite)
    @event.transition(:parked => :idling)
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_marshal_during_before_callbacks
    @machine.before_transition {|object, transition| Marshal.dump(object)}
    assert_nothing_raised { @event.fire(@object) }
  end
  
  def test_should_marshal_during_action
    @klass.class_eval do
      def save
        Marshal.dump(self)
      end
    end
    
    assert_nothing_raised { @event.fire(@object) }
  end
  
  def test_should_marshal_during_after_callbacks
    @machine.after_transition {|object, transition| Marshal.dump(object)}
    assert_nothing_raised { @event.fire(@object) }
  end
  
  def teardown
    self.class.send(:remove_const, 'Example')
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
