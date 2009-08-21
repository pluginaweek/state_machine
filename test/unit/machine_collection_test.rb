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
end

class MachineCollectionFireExplicitTest < Test::Unit::TestCase
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

class MachineCollectionFireExplicitWithTransactionsTest < Test::Unit::TestCase
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

class MachineCollectionFireExplicitWithValidationsTest < Test::Unit::TestCase
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

class MachineCollectionFireImplicitTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machines = StateMachine::MachineCollection.new
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    @saved = false
    @object = @klass.new
  end
  
  def default_test
  end
end

class MachineCollectionFireImplicitWithoutEventTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @object.state_event = nil
    @result = @machines.fire_event_attributes(@object, :save) { @saved = true }
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_run_action
    assert @saved
  end
  
  def test_should_not_transition_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_change_event_attribute
    assert_nil @object.state_event
  end
  
  def test_should_not_have_event_transition
    assert_nil @object.send(:state_event_transition)
  end
end

class MachineCollectionFireImplicitWithBlankEventTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @object.state_event = ''
    @result = @machines.fire_event_attributes(@object, :save) { @saved = true }
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_run_action
    assert @saved
  end
  
  def test_should_not_transition_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_change_event_attribute
    assert_nil @object.state_event
  end
  
  def test_should_not_have_event_transition
    assert_nil @object.send(:state_event_transition)
  end
end

class MachineCollectionFireImplicitWithInvalidEventTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @object.state_event = 'invalid'
    @result = @machines.fire_event_attributes(@object, :save) { @saved = true }
  end
  
  def test_should_not_be_successful
    assert_equal false, @result
  end
  
  def test_should_not_run_action
    assert !@saved
  end
  
  def test_should_not_transition_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_reset_event_attribute
    assert_equal :invalid, @object.state_event
  end
  
  def test_should_not_have_event_transition
    assert_nil @object.send(:state_event_transition)
  end
end

class MachineCollectionFireImplicitWithoutTransitionTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @object.state = 'idling'
    @object.state_event = 'ignite'
    @result = @machines.fire_event_attributes(@object, :save) { @saved = true }
  end
  
  def test_should_not_be_successful
    assert_equal false, @result
  end
  
  def test_should_not_run_action
    assert !@saved
  end
  
  def test_should_not_transition_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_not_reset_event_attribute
    assert_equal :ignite, @object.state_event
  end
  
  def test_should_not_have_event_transition
    assert_nil @object.send(:state_event_transition)
  end
end

class MachineCollectionFireImplicitWithTransitionTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @state_event = nil
    
    @object.state_event = 'ignite'
    @result = @machines.fire_event_attributes(@object, :save) do
      @state_event = @object.state_event
      @saved = true
    end
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_run_action
    assert @saved
  end
  
  def test_should_not_have_event_while_running_action
    assert_nil @state_event
  end
  
  def test_should_transition_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_reset_event_attribute
    assert_nil @object.state_event
  end
  
  def test_should_not_have_event_transition
    assert_nil @object.send(:state_event_transition)
  end
  
  def test_should_not_be_successful_if_fired_again
    @object.state_event = 'ignite'
    assert !@machines.fire_event_attributes(@object, :save) { true }
  end
end

class MachineCollectionFireImplicitWithNonBooleanResultTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @action_value = Object.new
    
    @object.state_event = 'ignite'
    @result = @machines.fire_event_attributes(@object, :save) do
      @saved = true
      @action_value
    end
  end
  
  def test_should_be_successful
    assert_equal @action_value, @result
  end
  
  def test_should_run_action
    assert @saved
  end
  
  def test_should_transition_state
    assert_equal 'idling', @object.state
  end
end

class MachineCollectionFireImplicitWithActionFailureTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @object.state_event = 'ignite'
    @result = @machines.fire_event_attributes(@object, :save) { false }
  end
  
  def test_should_not_be_successful
    assert_equal false, @result
  end
  
  def test_should_not_transition_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_reset_event_attribute
    assert_equal :ignite, @object.state_event
  end
  
  def test_should_not_have_event_transition
    assert_nil @object.send(:state_event_transition)
  end
end

class MachineCollectionFireImplicitWithActionErrorTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @object.state_event = 'ignite'
    assert_raise(ArgumentError) { @machines.fire_event_attributes(@object, :save) { raise ArgumentError } }
  end
  
  def test_should_not_transition_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_reset_event_attribute
    assert_equal :ignite, @object.state_event
  end
  
  def test_should_not_have_event_transition
    assert_nil @object.send(:state_event_transition)
  end
end

class MachineCollectionFireImplicitPartialTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @state_event = nil
    @state_event_transition = nil
    
    @object.state_event = 'ignite'
    @result = @machines.fire_event_attributes(@object, :save, false) do
      @state_event = @object.state_event
      @state_event_transition = @object.send(:state_event_transition)
      true
    end
  end
  
  def test_should_be_successful
    assert @result
  end
  
  def test_should_not_have_event_while_running_action
    assert_nil @state_event
  end
  
  def test_should_not_have_event_transition_while_running_action
    assert_nil @state_event_transition
  end
  
  def test_should_transition_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_reset_event_attribute
    assert_nil @object.state_event
  end
  
  def test_should_have_event_transition
    assert_not_nil @object.send(:state_event_transition)
  end
  
  def test_should_reset_event_after_next_fire_on_success
    assert @machines.fire_event_attributes(@object, :save) { true }
    assert_equal 'idling', @object.state
    assert_nil @object.state_event
  end
  
  def test_should_reset_event_transition_after_next_fire_on_success
    assert @machines.fire_event_attributes(@object, :save) { true }
    assert_nil @object.send(:state_event_transition)
  end
  
  def test_should_guard_transition_after_next_fire_on_success
    @machines.fire_event_attributes(@object, :save) { true }
    
    @object.state = 'idling'
    @object.state_event = 'ignite'
    assert !@machines.fire_event_attributes(@object, :save) { true }
  end
  
  def test_should_rollback_all_attributes_after_next_fire_on_failure
    assert !@machines.fire_event_attributes(@object, :save) { false }
    assert_equal 'parked', @object.state
    assert_equal :ignite, @object.state_event
    assert_nil @object.send(:state_event_transition)
    
    @object.state = 'idling'
    assert !@machines.fire_event_attributes(@object, :save) { false }
  end
  
  def test_should_guard_transition_after_next_fire_on_failure
    @machines.fire_event_attributes(@object, :save) { false }
    
    @object.state = 'idling'
    assert !@machines.fire_event_attributes(@object, :save) { true }
  end
  
  def test_should_rollback_all_attributes_after_next_fire_on_error
    assert_raise(ArgumentError) { @machines.fire_event_attributes(@object, :save) { raise ArgumentError } }
    assert_equal 'parked', @object.state
    assert_equal :ignite, @object.state_event
    assert_nil @object.send(:state_event_transition)
  end
  
  def test_should_guard_transition_after_next_fire_on_error
    begin
      @machines.fire_event_attributes(@object, :save) { raise ArgumentError }
    rescue ArgumentError
    end
    
    @object.state = 'idling'
    assert !@machines.fire_event_attributes(@object, :save) { true }
  end
end

class MachineCollectionFireImplicitPartialWithCallbacksTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @object.state_event = 'ignite'
  end
  
  def test_should_run_before_callbacks
    ran_callback = false
    @machine.before_transition { ran_callback = true }
    @machines.fire_event_attributes(@object, :save, false) { true }
    
    assert ran_callback
  end
  
  def test_should_not_have_event_during_before_callbacks
    state_event = nil
    @machine.before_transition {|object, transition| state_event = object.state_event }
    @machines.fire_event_attributes(@object, :save, false) { true }
    
    assert_nil state_event
  end
  
  def test_should_not_have_event_transition_during_before_callbacks
    state_event_transition = nil
    @machine.before_transition {|object, transition| state_event_transition = object.send(:state_event_transition) }
    @machines.fire_event_attributes(@object, :save, false) { true }
    
    assert_nil state_event_transition
  end
  
  def test_should_not_run_after_callbacks
    ran_callback = false
    @machine.after_transition { ran_callback = true }
    @machines.fire_event_attributes(@object, :save, false) { true }
    
    assert !ran_callback
  end
  
  def test_should_not_have_event_during_after_callbacks
    state_event = nil
    @machine.after_transition {|object, transition| state_event = object.state_event }
    @machines.fire_event_attributes(@object, :save, false) { true }
    
    assert_nil state_event
  end
  
  def test_should_not_have_event_transition_during_after_callbacks
    state_event_transition = nil
    @machine.after_transition {|object, transition| state_event_transition = object.send(:state_event_transition) }
    @machines.fire_event_attributes(@object, :save, false) { true }
    
    assert_nil state_event_transition
  end
end

class MachineCollectionFireImplicitNestedPartialTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @partial_result = nil
    
    @object.state_event = 'ignite'
    @result = @machines.fire_event_attributes(@object, :save) do
      @partial_result = @machines.fire_event_attributes(@object, :save, false) { true }
      true
    end
  end
  
  def test_should_be_successful
    assert @result
  end
  
  def test_should_have_successful_partial_fire
    assert @partial_result
  end
  
  def test_should_transition_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_reset_event_attribute
    assert_nil @object.state_event
  end
  
  def test_should_reset_event_transition_attribute
    assert_nil @object.send(:state_event_transition)
  end
end

class MachineCollectionFireImplicitWithDifferentActionsTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @machines[:alarm_state] = @alarm_machine = StateMachine::Machine.new(@klass, :alarm_state, :initial => :active, :action => :save_alarm)
    @alarm_machine.event :disable do
      transition :active => :off
    end
    
    @saved = false
    @object = @klass.new
    @object.state_event = 'ignite'
    @object.alarm_state_event = 'disable'
    
    @machines.fire_event_attributes(@object, :save) { true }
  end
  
  def test_should_transition_states_for_action
    assert_equal 'idling', @object.state
  end
  
  def test_should_reset_event_attribute_for_action
    assert_nil @object.state_event
  end
  
  def test_should_reset_event_transition_attribute_for_action
    assert_nil @object.send(:state_event_transition)
  end
  
  def test_should_not_transition_states_for_other_actions
    assert_equal 'active', @object.alarm_state
  end
  
  def test_should_not_reset_event_attributes_for_other_actions
    assert_equal :disable, @object.alarm_state_event
  end
end

class MachineCollectionFireImplicitWithSameActionsTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @machines[:alarm_state] = @alarm_machine = StateMachine::Machine.new(@klass, :alarm_state, :initial => :active, :action => :save)
    @alarm_machine.event :disable do
      transition :active => :off
    end
    
    @saved = false
    @object = @klass.new
    @object.state_event = 'ignite'
    @object.alarm_state_event = 'disable'
    
    @machines.fire_event_attributes(@object, :save) { true }
  end
  
  def test_should_transition_all_states_for_action
    assert_equal 'idling', @object.state
    assert_equal 'off', @object.alarm_state
  end
  
  def test_should_reset_all_event_attributes_for_action
    assert_nil @object.state_event
    assert_nil @object.alarm_state_event
  end
end

class MachineCollectionFireImplicitWithValidationsTest < Test::Unit::TestCase
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
    @machines[:state] = @machine = StateMachine::Machine.new(@klass, :state, :initial => :parked, :action => :save, :integration => :custom)
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    @object = @klass.new
  end
  
  def test_should_invalidate_if_event_is_invalid
    @object.state_event = 'invalid'
    @machines.fire_event_attributes(@object, :save) { true }
    
    assert !@object.errors.empty?
  end
  
  def test_should_invalidate_if_no_transition_exists
    @object.state = 'idling'
    @object.state_event = 'ignite'
    @machines.fire_event_attributes(@object, :save) { true }
    
    assert !@object.errors.empty?
  end
  
  def test_should_not_invalidate_if_transition_exists
    @object.state_event = 'ignite'
    @machines.fire_event_attributes(@object, :save) { true }
    
    assert @object.errors.empty?
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineCollectionFireImplicitWithCustomMachineNameTest < MachineCollectionFireImplicitTest
  def setup
    super
    
    @object.state_event = 'ignite'
  end
  
  def test_should_be_successful_on_complete_file
    assert @machines.fire_event_attributes(@object, :save) { true }
    assert_equal 'idling', @object.state
    assert_nil @object.state_event
    assert_nil @object.send(:state_event_transition)
  end
  
  def test_should_be_successful_on_partial_fire
    @machines.fire_event_attributes(@object, :save, false) { true }
    assert_equal 'idling', @object.state
    assert_nil @object.state_event
    assert_not_nil @object.send(:state_event_transition)
  end
end

class MachineFireImplicitWithMarshallingTest < MachineCollectionFireImplicitTest
  def setup
    super
    self.class.const_set('Example', @klass)
    
    @object.state_event = 'ignite'
  end
  
  def test_should_marshal_during_before_callbacks
    @machine.before_transition {|object, transition| Marshal.dump(object)}
    assert_nothing_raised { @machines.fire_event_attributes(@object, :save) { true } }
  end
  
  def test_should_marshal_during_action
    assert_nothing_raised do
      @machines.fire_event_attributes(@object, :save) do
         Marshal.dump(@object)
         true
      end
    end
  end
  
  def test_should_marshal_during_after_callbacks
    @machine.after_transition {|object, transition| Marshal.dump(object)}
    assert_nothing_raised { @machines.fire_event_attributes(@object, :save) { true } }
  end
  
  def teardown
    self.class.send(:remove_const, 'Example')
  end
end

class MachineFireImplicitPartialWithMarshallingTest < MachineCollectionFireImplicitTest
  def setup
    super
    self.class.const_set('Example', @klass)
    
    @object.state_event = 'ignite'
  end
  
  def test_should_marshal_during_before_callbacks
    @machine.before_transition {|object, transition| Marshal.dump(object)}
    assert_nothing_raised do
      @machines.fire_event_attributes(@object, :save, false) { true }
      @machines.fire_event_attributes(@object, :save) { true }
    end
  end
  
  def test_should_marshal_during_action
    assert_nothing_raised do
      @machines.fire_event_attributes(@object, :save, false) do
         Marshal.dump(@object)
         true
      end
      
      @machines.fire_event_attributes(@object, :save) do
         Marshal.dump(@object)
         true
      end
    end
  end
  
  def test_should_marshal_during_after_callbacks
    @machine.after_transition {|object, transition| Marshal.dump(object)}
    assert_nothing_raised do
      @machines.fire_event_attributes(@object, :save, false) { true }
      @machines.fire_event_attributes(@object, :save) { true }
    end
  end
  
  def teardown
    self.class.send(:remove_const, 'Example')
  end
end
