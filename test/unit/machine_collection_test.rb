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
    
    @klass = Class.new do
      def initialize(attributes = {})
        attributes.each do |attribute, value|
          self.send("#{attribute}=", value)
        end
        
        super()
      end
    end
    
    @machines[:state] = StateMachine::Machine.new(@klass, :state, :initial => :parked)
    @machines[:alarm_state] = StateMachine::Machine.new(@klass, :alarm_state, :initial => :active)
  end
  
  def test_should_set_states_if_nil
    object = @klass.new
    assert_equal 'parked', object.state
    assert_equal 'active', object.alarm_state
  end
  
  def test_should_set_states_if_empty
    object = @klass.new(:state => '', :alarm_state => '')
    assert_equal 'parked', object.state
    assert_equal 'active', object.alarm_state
  end
  
  def test_should_not_set_states_if_not_empty
    object = @klass.new(:state => 'idling', :alarm_state => 'off')
    assert_equal 'idling', object.state
    assert_equal 'off', object.alarm_state
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
