require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class EventCollectionByDefaultTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @events = StateMachine::EventCollection.new(@machine)
  end
  
  def test_should_not_have_any_nodes
    assert_equal 0, @events.length
  end
  
  def test_should_have_a_machine
    assert_equal @machine, @events.machine
  end
  
  def test_should_not_have_any_valid_events_for_an_object
    assert @events.valid_for(@object).empty?
  end
  
  def test_should_not_have_any_transitions_for_an_object
    assert @events.transitions_for(@object).empty?
  end
end

class EventCollectionTest < Test::Unit::TestCase
  def setup
    machine = StateMachine::Machine.new(Class.new, :namespace => 'alarm')
    @events = StateMachine::EventCollection.new(machine)
    
    @events << @open = StateMachine::Event.new(machine, :enable)
  end
  
  def test_should_index_by_name
    assert_equal @open, @events[:enable, :name]
  end
  
  def test_should_index_by_name_by_default
    assert_equal @open, @events[:enable]
  end
  
  def test_should_index_by_qualified_name
    assert_equal @open, @events[:enable_alarm, :qualified_name]
  end
end

class EventCollectionWithEventsWithTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @events = StateMachine::EventCollection.new(@machine)
    
    @machine.state :idling, :stalled
    @machine.event :ignite
    
    @events << @ignite = StateMachine::Event.new(@machine, :ignite)
    @ignite.transition :parked => :idling
    @ignite.transition :stalled => :idling
  end
  
  def test_should_only_include_valid_events_for_an_object
    object = @klass.new
    object.state = 'parked'
    assert_equal [@ignite], @events.valid_for(object)
    
    object.state = 'stalled'
    assert_equal [@ignite], @events.valid_for(object)
    
    object.state = 'idling'
    assert_equal [], @events.valid_for(object)
  end
  
  def test_should_only_include_valid_transitions_for_an_object
    object = @klass.new
    object.state = 'parked'
    assert_equal [{:object => object, :attribute => :state, :event => :ignite, :from => 'parked', :to => 'idling'}], @events.transitions_for(object).map {|transition| transition.attributes}
    
    object.state = 'stalled'
    assert_equal [{:object => object, :attribute => :state, :event => :ignite, :from => 'stalled', :to => 'idling'}], @events.transitions_for(object).map {|transition| transition.attributes}
    
    object.state = 'idling'
    assert_equal [], @events.transitions_for(object)
  end
  
  def test_should_filter_valid_transitions_for_an_object_if_requirements_specified
    object = @klass.new
    assert_equal [{:object => object, :attribute => :state, :event => :ignite, :from => 'stalled', :to => 'idling'}], @events.transitions_for(object, :from => :stalled).map {|transition| transition.attributes}
    assert_equal [], @events.transitions_for(object, :from => :idling).map {|transition| transition.attributes}
  end
end

class EventCollectionWithMultipleEventsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @events = StateMachine::EventCollection.new(@machine)
    
    @machine.state :first_gear
    @machine.event :park, :shift_down
    
    @events << @park = StateMachine::Event.new(@machine, :park)
    @park.transition :first_gear => :parked
    
    @events << @shift_down = StateMachine::Event.new(@machine, :shift_down)
    @shift_down.transition :first_gear => :parked
  end
  
  def test_should_only_include_all_valid_events_for_an_object
    object = @klass.new
    object.state = 'first_gear'
    assert_equal [@park, @shift_down], @events.valid_for(object)
  end
end

class EventCollectionWithoutMachineActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @events = StateMachine::EventCollection.new(@machine)
    
    @machine.event :ignite
    @events << StateMachine::Event.new(@machine, :ignite)
    
    @object = @klass.new
  end
  
  def test_should_not_have_an_attribute_transition
    assert_nil @events.attribute_transition_for(@object)
  end
end

class EventCollectionAttributeWithMachineActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @events = StateMachine::EventCollection.new(@machine)
    
    @machine.event :ignite
    @machine.state :parked, :idling
    @events << @ignite = StateMachine::Event.new(@machine, :ignite)
    
    @object = @klass.new
  end
  
  def test_should_not_have_transition_if_nil
    @object.state_event = nil
    assert_nil @events.attribute_transition_for(@object)
  end
  
  def test_should_not_have_transition_if_empty
    @object.state_event = ''
    assert_nil @events.attribute_transition_for(@object)
  end
  
  def test_should_have_invalid_transition_if_invalid_event_specified
    @object.state_event = 'invalid'
    assert_equal false, @events.attribute_transition_for(@object)
  end
  
  def test_should_have_invalid_transition_if_event_cannot_be_fired
    @object.state_event = 'ignite'
    assert_equal false, @events.attribute_transition_for(@object)
  end
  
  def test_should_have_valid_transition_if_event_can_be_fired
    @ignite.transition :parked => :idling
    @object.state_event = 'ignite'
    
    assert_instance_of StateMachine::Transition, @events.attribute_transition_for(@object)
  end
  
  def test_should_have_valid_transition_if_already_defined_in_transition_cache
    @ignite.transition :parked => :idling
    @object.state_event = nil
    @object.send(:state_event_transition=, transition = @ignite.transition_for(@object))
    
    assert_equal transition, @events.attribute_transition_for(@object)
  end
  
  def test_should_use_transition_cache_if_both_event_and_transition_are_present
    @ignite.transition :parked => :idling
    @object.state_event = 'ignite'
    @object.send(:state_event_transition=, transition = @ignite.transition_for(@object))
    
    assert_equal transition, @events.attribute_transition_for(@object)
  end
end

class EventCollectionAttributeWithNamespacedMachineTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :namespace => 'alarm', :initial => :active, :action => :save)
    @events = StateMachine::EventCollection.new(@machine)
    
    @machine.event :disable
    @machine.state :active, :off
    @events << @disable = StateMachine::Event.new(@machine, :disable)
    
    @object = @klass.new
  end
  
  def test_should_not_have_transition_if_nil
    @object.state_event = nil
    assert_nil @events.attribute_transition_for(@object)
  end
  
  def test_should_have_invalid_transition_if_event_cannot_be_fired
    @object.state_event = 'disable'
    assert_equal false, @events.attribute_transition_for(@object)
  end
  
  def test_should_have_valid_transition_if_event_can_be_fired
    @disable.transition :active => :off
    @object.state_event = 'disable'
    
    assert_instance_of StateMachine::Transition, @events.attribute_transition_for(@object)
  end
end

class EventCollectionWithValidationsTest < Test::Unit::TestCase
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
      
      def initialize
        @errors = []
        super
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save, :integration => :custom)
    @events = StateMachine::EventCollection.new(@machine)
    
    @machine.event :ignite
    @machine.state :parked, :idling
    @events << @ignite = StateMachine::Event.new(@machine, :ignite)
    
    @object = @klass.new
  end
  
  def test_should_invalidate_if_invalid_event_specified
    @object.state_event = 'invalid'
    @events.attribute_transition_for(@object, true)
    
    assert_equal ['is invalid'], @object.errors
  end
  
  def test_should_invalidate_if_event_cannot_be_fired
    @object.state = 'idling'
    @object.state_event = 'ignite'
    @events.attribute_transition_for(@object, true)
    
    assert_equal ['cannot transition when idling'], @object.errors
  end
  
  def test_should_invalidate_with_friendly_name_if_invalid_event_specified
    # Add a valid nil state
    @machine.state nil
    
    @object.state = nil
    @object.state_event = 'ignite'
    @events.attribute_transition_for(@object, true)
    
    assert_equal ['cannot transition when nil'], @object.errors
  end
  
  def test_should_not_invalidate_event_can_be_fired
    @ignite.transition :parked => :idling
    @object.state_event = 'ignite'
    @events.attribute_transition_for(@object, true)
    
    assert_equal [], @object.errors
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class EventCollectionWithCustomMachineAttributeTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :state, :attribute => :state_id, :initial => :parked, :action => :save)
    @events = StateMachine::EventCollection.new(@machine)
    
    @machine.event :ignite
    @machine.state :parked, :idling
    @events << @ignite = StateMachine::Event.new(@machine, :ignite)
    
    @object = @klass.new
  end
  
  def test_should_not_have_transition_if_nil
    @object.state_event = nil
    assert_nil @events.attribute_transition_for(@object)
  end
  
  def test_should_have_valid_transition_if_event_can_be_fired
    @ignite.transition :parked => :idling
    @object.state_event = 'ignite'
    
    assert_instance_of StateMachine::Transition, @events.attribute_transition_for(@object)
  end
end
