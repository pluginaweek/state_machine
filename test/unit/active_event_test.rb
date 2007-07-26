require File.dirname(__FILE__) + '/../test_helper'

class PluginAWeek::Has::States::EventTest < Test::Unit::TestCase
  cattr_accessor :active_states
  attr_accessor :state
  
  def setup
    @@active_states = {
      :off => states(:switch_off),
      :on => states(:switch_on)
    }
    
    @event = Event.new(:name => 'execute', :owner_type => self.class.name)
    @event.extend PluginAWeek::Has::States::ActiveEvent
    class << @event
      public :transitions
    end
    
    @callbacks = []
  end
  
  def after_execute
    @callbacks << 'after_execute'
    true
  end
  
  def after_turn_on
    @callbacks << 'after_turn_on'
    true
  end
  
  def return_false
    false
  end
  
  def callback(method)
    @callbacks << method
  end
  
  def test_should_user_owner_type_for_owner_class
    assert_equal self.class, @event.owner_class
  end
  
  def test_should_not_cache_owner_class
    owner_class = @event.owner_class
    @event.owner_type = 'Event'
    assert_not_equal owner_class, @event.owner_class
    assert_equal Event, @event.owner_class
  end
  
  def test_should_raise_exception_if_transitioning_to_unknown_state
    assert_raise(PluginAWeek::Has::States::StateNotActive) {@event.transition_to :invalid_state}
  end
  
  def test_should_raise_exception_if_transitioning_to_inactive_state
    @@active_states.delete(:on)
    assert_raise(PluginAWeek::Has::States::StateNotActive) {@event.transition_to :on}
  end
  
  def test_should_raise_exception_if_transitioning_from_unknown_state
    assert_raise(PluginAWeek::Has::States::StateNotActive) {@event.transition_to :off, :from => :invalid_state}
  end
  
  def test_should_raise_exception_if_transitioning_from_inactive_state
    @@active_states.delete(:off)
    assert_raise(PluginAWeek::Has::States::StateNotActive) {@event.transition_to :on, :from => :off}
  end
  
  def test_should_raise_exception_if_using_invalid_option
    assert_raise(ArgumentError) {@event.transition_to :on, :invalid_option => true}
  end
  
  def test_should_use_all_active_states_if_from_state_not_specified
    @event.transition_to :on
    expected_transitions = [
      create_transition(:off, :on),
      create_transition(:on, :on)
    ]
    
    assert_equal 2, @event.transitions.size
    assert (expected_transitions - @event.transitions).empty?
  end
  
  def test_should_create_single_transition_if_transitioning_from_single_state
    @event.transition_to :on, :from => :off
    
    assert_equal 1, @event.transitions.size
    assert_equal [create_transition(:off, :on)], @event.transitions
  end
  
  def test_should_create_multiple_transitions_if_transitioning_from_multiple_states
    @event.transition_to :on, :from => [:off, :on]
    expected_transitions = [
      create_transition(:off, :on),
      create_transition(:on, :on)
    ]
    
    assert_equal 2, @event.transitions.size
    assert (expected_transitions - @event.transitions).empty?
  end
  
  def test_should_allow_transitions_with_the_same_to_and_from_states
    @event.transition_to :on, :from => :on
    @event.transition_to :on, :from => :on
    
    assert_equal 2, @event.transitions.size
    assert_equal [create_transition(:on, :on)] * 2, @event.transitions
  end
  
  def test_should_allow_loopback_transition
    @event.transition_to :on, :from => :on
    
    assert_equal 1, @event.transitions.size
    assert_equal [create_transition(:on, :on)], @event.transitions
  end
  
  def test_should_not_have_possible_transitions_if_no_transitions_were_created
    assert_equal [], @event.possible_transitions_from(nil)
  end
  
  def test_should_not_have_possible_transitions_if_from_state_doesnt_match_current_state
    @event.transition_to :on, :from => :off
    
    assert_equal [], @event.possible_transitions_from(states(:switch_on))
  end
  
  def test_should_have_possible_transition_if_from_state_matches_current_state
    @event.transition_to :on, :from => :off
    
    assert_equal [create_transition(:off, :on)], @event.possible_transitions_from(states(:switch_off))
  end
  
  def test_should_have_multiple_possible_transitions_if_from_state_matches_current_state
    @event.transition_to :on, :from => :on
    @event.transition_to :off, :from => :on
    
    expected_transitions = [
      create_transition(:on, :on),
      create_transition(:on, :off)
    ]
    assert_equal expected_transitions, @event.possible_transitions_from(states(:switch_on))
  end
  
  def test_should_clone_callbacks_when_cloned
    dup_event = @event.dup
    
    assert_not_equal @event.object_id, dup_event.object_id
    assert_not_equal @event.callbacks.object_id, dup_event.callbacks.object_id
  end
  
  def test_should_clone_transitions_when_cloned
    dup_event = @event.dup
    
    assert_not_equal @event.object_id, dup_event.object_id
    assert_not_equal @event.transitions.object_id, dup_event.transitions.object_id
  end
  
  def test_should_return_false_if_not_fired
    assert !@event.fire(self)
  end
  
  def test_should_not_change_state_if_not_fired
    self.state = states(:switch_on)
    original_state = self.state
    
    @event.transition_to :on, :from => :off
    @event.fire(self)
    
    assert_same original_state, self.state
  end
  
  def test_should_not_record_state_change_if_not_fired
    @event.fire(self)
    
    assert_nil @recorded_event
    assert_nil @recorded_from_state
    assert_nil @recorded_to_state
  end
  
  def test_should_not_invoke_callbacks_if_not_fired
    @event.fire(self)
    
    assert @callbacks.empty?
  end
  
  def test_should_return_true_if_fired
    self.state = states(:switch_off)
    @event.transition_to :on, :from => :off
    
    assert @event.fire(self)
  end
  
  def test_should_change_state_if_fired
    self.state = states(:switch_off)
    original_state = self.state
    
    @event.transition_to :on, :from => :off
    @event.fire(self)
    
    assert_not_equal original_state, self.state
    assert_equal states(:switch_on), self.state
  end
  
  def test_should_record_state_change_if_fired
    self.state = states(:switch_off)
    
    @event.transition_to :on, :from => :off
    @event.fire(self)
    
    assert_equal @event, @recorded_event
    assert_equal states(:switch_off), @recorded_from_state
    assert_equal states(:switch_on), @recorded_to_state
  end
  
  def test_should_invoke_callbacks_if_fired
    self.state = states(:switch_off)
    
    @event.transition_to :on, :from => :off
    @event.fire(self)
    
    expected_callbacks = %w(before_exit_off before_enter_on after_exit_off after_enter_on after_execute)
    assert_equal expected_callbacks, @callbacks
  end
  
  def test_should_invoke_custom_callbacks_if_fired
    self.state = states(:switch_off)
    
    @event.transition_to :on, :from => :off
    @event.callbacks << :after_turn_on
    @event.fire(self)
    
    expected_callbacks = %w(before_exit_off before_enter_on after_exit_off after_enter_on after_turn_on after_execute)
    assert_equal expected_callbacks, @callbacks
  end
  
  def test_should_fail_if_callback_returns_false
    self.state = states(:switch_off)
    
    @event.transition_to :on, :from => :off
    @event.callbacks << :after_turn_on
    @event.callbacks << :return_false
    
    assert !@event.fire(self)
  end
  
  private
  def create_transition(from_state_name, to_state_name)
    PluginAWeek::Has::States::StateTransition.new(@@active_states[from_state_name], @@active_states[to_state_name], {})
  end
  
  def record_state_change(event, from_state, to_state)
    @recorded_event, @recorded_from_state, @recorded_to_state = event, from_state, to_state
  end
end