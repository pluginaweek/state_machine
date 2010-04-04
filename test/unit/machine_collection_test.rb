require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MachineCollectionByDefaultTest < Test::Unit::TestCase
  def setup
    @machines = StateMachine::MachineCollection.new
  end
  
  def test_should_not_have_any_machines
    assert @machines.empty?
  end
end

class MachineCollectionStateInitializationTest < Test::Unit::TestCase
  def setup
    @machines = StateMachine::MachineCollection.new
    
    @klass = Class.new
    
    @machines[:state] = StateMachine::Machine.new(@klass, :state, :initial => :parked)
    @machines[:alarm_state] = StateMachine::Machine.new(@klass, :alarm_state, :initial => lambda {|object| :active})
    @machines[:alarm_state].state :active, :value => lambda {'active'}
    
    # Prevent the auto-initialization hook from firing
    @klass.class_eval do
      def initialize
      end
    end
    
    @object = @klass.new
    @object.state = nil
    @object.alarm_state = nil
  end
  
  def test_should_set_states_if_nil
    @machines.initialize_states(@object)
    
    assert_equal 'parked', @object.state
    assert_equal 'active', @object.alarm_state
  end
  
  def test_should_set_states_if_empty
    @object.state = ''
    @object.alarm_state = ''
    @machines.initialize_states(@object)
    
    assert_equal 'parked', @object.state
    assert_equal 'active', @object.alarm_state
  end
  
  def test_should_not_set_states_if_not_empty
    @object.state = 'idling'
    @object.alarm_state = 'off'
    @machines.initialize_states(@object)
    
    assert_equal 'idling', @object.state
    assert_equal 'off', @object.alarm_state
  end
  
  def test_should_only_initialize_static_states_if_dynamic_disabled
    @machines.initialize_states(@object, :dynamic => false)
    
    assert_equal 'parked', @object.state
    assert_nil @object.alarm_state
  end
  
  def test_should_only_initialize_dynamic_states_if_dynamic_enabled
    @machines.initialize_states(@object, :dynamic => true)
    
    assert_nil @object.state
    assert_equal 'active', @object.alarm_state
  end
  
  def test_should_not_set_states_if_ignored
    @machines.initialize_states(@object, :ignore => [:state, :alarm_state])
    
    assert_nil @object.state
    assert_nil @object.alarm_state
  end
  
  def test_should_set_states_if_not_ignored_and_nil
    @machines.initialize_states(@object, :ignore => [])
    
    assert_equal 'parked', @object.state
    assert_equal 'active', @object.alarm_state
  end
  
  def test_should_set_states_if_not_ignored_and_empty
    @object.state = ''
    @object.alarm_state = ''
    @machines.initialize_states(@object, :ignore => [])
    
    assert_equal 'parked', @object.state
    assert_equal 'active', @object.alarm_state
  end
  
  def test_should_set_states_if_not_ignored_and_not_empty
    @object.state = 'idling'
    @object.alarm_state = 'inactive'
    @machines.initialize_states(@object, :ignore => [])
    
    assert_equal 'parked', @object.state
    assert_equal 'active', @object.alarm_state
  end
  
  def test_should_not_modify_ignore_option
    ignore = ['state', 'alarm_state']
    @machines.initialize_states(@object, :ignore => ignore)
    
    assert_nil @object.state
    assert_nil @object.alarm_state
    assert_equal ['state', 'alarm_state'], ignore
  end
end

class MachineCollectionFireTest < Test::Unit::TestCase
  def setup
    @machines = StateMachine::MachineCollection.new
    
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    
    # First machine
    @machines[:state] = @state = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @state.event :ignite do
      transition :parked => :idling
    end
    @state.event :park do
      transition :idling => :parked
    end
    
    # Second machine
    @machines[:alarm_state] = @alarm_state = StateMachine::Machine.new(@klass, :alarm_state, :initial => :active, :action => :save, :namespace => 'alarm')
    @alarm_state.event :enable do
      transition :off => :active
    end
    @alarm_state.event :disable do
      transition :active => :off
    end
    
    @object = @klass.new
  end
  
  def test_should_raise_exception_if_invalid_event_specified
    exception = assert_raise(StateMachine::InvalidEvent) { @machines.fire_events(@object, :invalid) }
    assert_equal ':invalid is an unknown state machine event', exception.message
    
    exception = assert_raise(StateMachine::InvalidEvent) { @machines.fire_events(@object, :ignite, :invalid) }
    assert_equal ':invalid is an unknown state machine event', exception.message
  end
  
  def test_should_fail_if_any_event_cannot_transition
    assert !@machines.fire_events(@object, :park, :disable_alarm)
    assert_equal 'parked', @object.state
    assert_equal 'active', @object.alarm_state
    assert !@object.saved
    
    assert !@machines.fire_events(@object, :ignite, :enable_alarm)
    assert_equal 'parked', @object.state
    assert_equal 'active', @object.alarm_state
    assert !@object.saved
  end
  
  def test_should_be_successful_if_all_events_transition
    assert @machines.fire_events(@object, :ignite, :disable_alarm)
    assert_equal 'idling', @object.state
    assert_equal 'off', @object.alarm_state
    assert @object.saved
  end
  
  def test_should_not_save_if_skipping_action
    assert @machines.fire_events(@object, :ignite, :disable_alarm, false)
    assert_equal 'idling', @object.state
    assert_equal 'off', @object.alarm_state
    assert !@object.saved
  end
end

class MachineCollectionFireWithTransactionsTest < Test::Unit::TestCase
  def setup
    @machines = StateMachine::MachineCollection.new
    
    @klass = Class.new do
      attr_accessor :allow_save
      
      def save
        @allow_save
      end
    end
    
    StateMachine::Integrations.const_set('Custom', Module.new do
      attr_reader :rolled_back
      
      def transaction(object)
        @rolled_back = yield
      end
    end)
    
    # First machine
    @machines[:state] = @state = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save, :integration => :custom)
    @state.event :ignite do
      transition :parked => :idling
    end
    
    # Second machine
    @machines[:alarm_state] = @alarm_state = StateMachine::Machine.new(@klass, :alarm_state, :initial => :active, :action => :save, :namespace => 'alarm', :integration => :custom)
    @alarm_state.event :disable do
      transition :active => :off
    end
    
    @object = @klass.new
  end
  
  def test_should_not_rollback_if_successful
    @object.allow_save = true
    
    assert @machines.fire_events(@object, :ignite, :disable_alarm)
    assert_equal true, @state.rolled_back
    assert_nil @alarm_state.rolled_back
    assert_equal 'idling', @object.state
    assert_equal 'off', @object.alarm_state
  end
  
  def test_should_rollback_if_not_successful
    @object.allow_save = false
    
    assert !@machines.fire_events(@object, :ignite, :disable_alarm)
    assert_equal false, @state.rolled_back
    assert_nil @alarm_state.rolled_back
    assert_equal 'parked', @object.state
    assert_equal 'active', @object.alarm_state
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineCollectionFireWithValidationsTest < Test::Unit::TestCase
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
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @state = StateMachine::Machine.new(@klass, :state, :initial => :parked, :integration => :custom)
    @state.event :ignite do
      transition :parked => :idling
    end
    
    @machines[:alarm_state] = @alarm_state = StateMachine::Machine.new(@klass, :alarm_state, :initial => :active, :namespace => 'alarm', :integration => :custom)
    @alarm_state.event :disable do
      transition :active => :off
    end
    
    @object = @klass.new
  end
  
  def test_should_not_invalidate_if_transitions_exist
    assert @machines.fire_events(@object, :ignite, :disable_alarm)
    assert_equal [], @object.errors
  end
  
  def test_should_invalidate_if_no_transitions_exist
    @object.state = 'idling'
    @object.alarm_state = 'off'
    
    assert !@machines.fire_events(@object, :ignite, :disable_alarm)
    assert_equal ['cannot transition via "ignite"', 'cannot transition via "disable_alarm"'], @object.errors
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineCollectionTransitionsWithoutEventsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    @object = @klass.new
    @object.state_event = nil
    @transitions = @machines.transitions(@object, :save)
  end
  
  def test_should_be_empty
    assert @transitions.empty?
  end
  
  def test_should_perform
    assert_equal true, @transitions.perform
  end
end

class MachineCollectionTransitionsWithBlankEventsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    @object = @klass.new
    @object.state_event = ''
    @transitions = @machines.transitions(@object, :save)
  end
  
  def test_should_be_empty
    assert @transitions.empty?
  end
  
  def test_should_perform
    assert_equal true, @transitions.perform
  end
end

class MachineCollectionTransitionsWithInvalidEventsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    @object = @klass.new
    @object.state_event = 'invalid'
    @transitions = @machines.transitions(@object, :save)
  end
  
  def test_should_be_empty
    assert @transitions.empty?
  end
  
  def test_should_not_perform
    assert_equal false, @transitions.perform
  end
end

class MachineCollectionTransitionsWithoutTransitionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    @object = @klass.new
    @object.state = 'idling'
    @object.state_event = 'ignite'
    @transitions = @machines.transitions(@object, :save)
  end
  
  def test_should_be_empty
    assert @transitions.empty?
  end
  
  def test_should_not_perform
    assert_equal false, @transitions.perform
  end
end

class MachineCollectionTransitionsWithTransitionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    @object = @klass.new
    @object.state_event = 'ignite'
    @transitions = @machines.transitions(@object, :save)
  end
  
  def test_should_not_be_empty
    assert_equal 1, @transitions.length
  end
  
  def test_should_perform
    assert_equal true, @transitions.perform
  end
end

class MachineCollectionTransitionsWithSameActionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    @machines[:status] = @machine = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :save)
    @machine.event :shift_up do
      transition :first_gear => :second_gear
    end
    
    @object = @klass.new
    @object.state_event = 'ignite'
    @object.status_event = 'shift_up'
    @transitions = @machines.transitions(@object, :save)
  end
  
  def test_should_not_be_empty
    assert_equal 2, @transitions.length
  end
  
  def test_should_perform
    assert_equal true, @transitions.perform
  end
end

class MachineCollectionTransitionsWithDifferentActionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @state = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @state.event :ignite do
      transition :parked => :idling
    end
    @machines[:status] = @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :persist)
    @status.event :shift_up do
      transition :first_gear => :second_gear
    end
    
    @object = @klass.new
    @object.state_event = 'ignite'
    @object.status_event = 'shift_up'
    @transitions = @machines.transitions(@object, :save)
  end
  
  def test_should_only_select_matching_actions
    assert_equal 1, @transitions.length
  end
end

class MachineCollectionTransitionsWithExisitingTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    @object = @klass.new
    @object.send(:state_event_transition=, StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling))
    @transitions = @machines.transitions(@object, :save)
  end
  
  def test_should_not_be_empty
    assert_equal 1, @transitions.length
  end
  
  def test_should_perform
    assert_equal true, @transitions.perform
  end
end

class MachineCollectionTransitionsWithCustomOptionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    @object = @klass.new
    @transitions = @machines.transitions(@object, :save, :after => false)
  end
  
  def test_should_use_custom_options
    assert @transitions.skip_after
  end
end

class MachineCollectionFireAttributesWithValidationsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_accessor :errors
      
      def initialize
        @errors = []
        super
      end
    end
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    class << @machine
      def invalidate(object, attribute, message, values = [])
        (object.errors ||= []) << generate_message(message, values)
      end
      
      def reset(object)
        object.errors = []
      end
    end
    
    @object = @klass.new
  end
  
  def test_should_invalidate_if_event_is_invalid
    @object.state_event = 'invalid'
    @machines.transitions(@object, :save)
    
    assert !@object.errors.empty?
  end
  
  def test_should_invalidate_if_no_transition_exists
    @object.state = 'idling'
    @object.state_event = 'ignite'
    @machines.transitions(@object, :save)
    
    assert !@object.errors.empty?
  end
  
  def test_should_not_invalidate_if_transition_exists
    @object.state_event = 'ignite'
    @machines.transitions(@object, :save)
    
    assert @object.errors.empty?
  end
end
