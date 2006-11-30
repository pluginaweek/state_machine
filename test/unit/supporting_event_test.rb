require File.dirname(__FILE__) + '/../test_helper'
require File.dirname(__FILE__) + '/../mocks/mock_transition'
require File.dirname(__FILE__) + '/../mocks/parallel_machine'

class PluginAWeek::Acts::StateMachine::SupportingClasses::Event
  attr_accessor :transitions
end

class SupportingEventTest < Test::Unit::TestCase
  const_set('SupportingEvent', PluginAWeek::Acts::StateMachine::SupportingClasses::Event)
  
  attr_accessor :state_name,
                :first_parallel,
                :second_parallel
  
  def setup
    @state_name = :off
    @record = events(:switch_turn_on)
    @transitions = {}
    @event_transitions = [
      MockTransition.new(:off, :on, true)
    ]
    @valid_state_names = [:off, :on]
  end
  
  def test_no_transitions
    @state_name = :on
    
    event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names)
    assert_equal [], event.next_states_for(self)
  end
  
  def test_transitions
    event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names)
    event.transitions = @event_transitions
    assert_equal [@event_transitions.first], event.next_states_for(self)
  end
  
  def test_invalid_key
    options = {:invalid_key => true}
    assert_raise(ArgumentError) {SupportingEvent.new(@record, options, @transitions, @valid_state_names)}
  end
  
  def test_initialize_with_block
    event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names) do
    end
    
    assert_instance_of SupportingEvent, event
  end
  
  def test_fire_with_no_transitions
    event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names)
    assert !event.fire(self)
  end
  
  def test_fire_with_failed_transitions
    event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names)
    event.transitions = [
      MockTransition.new(:off, :on, false)
    ]
    
    assert !event.fire(self)
    assert_nil @event_name
    assert_nil @from_state_name
    assert_nil @to_state_name
  end
  
  def test_fire_with_successful_transitions
    event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names)
    event.transitions = [
      MockTransition.new(:off, :on, true)
    ]
    
    assert event.fire(self)
    assert_equal :turn_on, @event_name
    assert_equal :off, @from_state_name
    assert_equal :on, @to_state_name
  end
  
  def test_fire_with_failed_then_successful_transition
    event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names)
    event.transitions = [
      MockTransition.new(:off, :on, false),
      MockTransition.new(:off, :on, true)
    ]
    
    assert event.fire(self)
    assert_equal :turn_on, @event_name
    assert_equal :off, @from_state_name
    assert_equal :on, @to_state_name
  end
  
  def test_fire_with_failed_parallel_state_machines
    @first_parallel = ParallelMachine.new(false)
    
    options = {:parallel => :first_parallel}
    event = SupportingEvent.new(@record, options, @transitions, @valid_state_names)
    event.transitions = [
      MockTransition.new(:off, :on, true)
    ]
    
    assert !event.fire(self)
    assert_equal :turn_on, @event_name
    assert_equal :off, @from_state_name
    assert_equal :on, @to_state_name
    assert @first_parallel.turn_on_called
  end
  
  def test_fire_with_successful_state_machines
    @first_parallel = ParallelMachine.new(true)
    
    options = {:parallel => :first_parallel}
    event = SupportingEvent.new(@record, options, @transitions, @valid_state_names)
    event.transitions = [
      MockTransition.new(:off, :on, true)
    ]
    
    assert event.fire(self)
    assert_equal :turn_on, @event_name
    assert_equal :off, @from_state_name
    assert_equal :on, @to_state_name
    assert @first_parallel.turn_on_called
  end
  
  def test_fire_with_multiple_machines
    @first_parallel = ParallelMachine.new(true)
    @second_parallel = ParallelMachine.new(true)
    
    options = {:parallel => [:first_parallel, {:second_parallel => :turn_on_now}]}
    event = SupportingEvent.new(@record, options, @transitions, @valid_state_names)
    event.transitions = [
      MockTransition.new(:off, :on, true)
    ]
    
    assert event.fire(self)
    assert_equal :turn_on, @event_name
    assert_equal :off, @from_state_name
    assert_equal :on, @to_state_name
    assert @first_parallel.turn_on_called
    assert !@second_parallel.turn_on_called
    assert @second_parallel.turn_on_now_called
  end
  
  def test_transition_to_with_invalid_to
    assert_raise(PluginAWeek::Acts::StateMachine::InvalidState) do
      event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names) do
        transition_to :invalid_to_state, :from => :off
      end
    end
  end
  
  def test_transition_to_with_invalid_from
    assert_raise(PluginAWeek::Acts::StateMachine::InvalidState) do
      event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names) do
        transition_to :on, :from => :invalid_from_state
      end
    end
  end
  
  def test_transition_to
    event = SupportingEvent.new(@record, {}, @transitions, @valid_state_names) do
      transition_to :on, :from => :off
    end
    
    assert event.transitions == [MockTransition.new(:off, :on, true)]
  end
  
  private
  def record_transition(event_name, from_state_name, to_state_name)
    @event_name, @from_state_name, @to_state_name = event_name, from_state_name, to_state_name
  end
end