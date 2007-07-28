require File.dirname(__FILE__) + '/../test_helper'

class ActiveEventTest < Test::Unit::TestCase
  def setup
    Switch.active_states = {
      :off => PluginAWeek::Has::States::ActiveState.new(Switch, states(:switch_off)),
      :on => PluginAWeek::Has::States::ActiveState.new(Switch, states(:switch_on))
    }
    
    @original_instance_methods = Switch.instance_methods
    @event = PluginAWeek::Has::States::ActiveEvent.new(Switch, events(:switch_turn_on))
  end
  
  def test_should_raise_exception_if_invalid_option_used_on_create
    assert_raise(ArgumentError) {PluginAWeek::Has::States::ActiveEvent.new(Switch, Event.new, :invalid_option => true)}
  end
  
  def test_should_set_owner_class_to_initialized_class
    assert_equal Switch, @event.owner_class
  end
  
  def test_should_allow_owner_class_to_be_modified
    @event.owner_class = self.class
    assert_equal self.class, @event.owner_class
  end
  
  def test_should_have_no_transitions_by_default
    assert_equal [], @event.transitions
  end
  
  def test_should_not_add_after_callback_on_initialization
    expected_callbacks = {:before => [], :after => []}
    assert_equal expected_callbacks, @event.callbacks
  end
  
  def test_should_be_able_to_read_event_being_represented
    assert_instance_of Event, @event.record
  end
  
  def test_should_allow_custom_callbacks_in_addition_to_default
    event = PluginAWeek::Has::States::ActiveEvent.new(Switch, events(:switch_turn_on), :after => :return_false)
    expected_callbacks = {:before => [], :after => [:return_false]}
    assert_equal expected_callbacks, event.callbacks
  end
  
  def test_should_create_event_action_method
    assert Switch.instance_methods.include?('turn_on!')
  end
  
  def test_should_create_event_callback_methods
    assert Switch.singleton_methods.include?('before_turn_on')
    assert Switch.singleton_methods.include?('after_turn_on')
  end
  
  def test_should_forward_missing_methods_to_record
    assert_equal 101, @event.id
    assert_equal 'turn_on', @event.name
    assert_equal 'Turn On', @event.human_name
    assert_equal :turn_on, @event.to_sym
  end
  
  def test_should_not_cache_owner_class
    owner_class = @event.owner_class
    @event.owner_class = self.class
    assert_not_equal owner_class, @event.owner_class
    assert_equal self.class, @event.owner_class
  end
  
  def test_should_raise_exception_if_transitioning_to_unknown_state
    assert_raise(PluginAWeek::Has::States::StateNotActive) {@event.transition_to :invalid_state}
  end
  
  def test_should_raise_exception_if_transitioning_to_inactive_state
    Switch.active_states.delete(:on)
    assert_raise(PluginAWeek::Has::States::StateNotActive) {@event.transition_to :on}
  end
  
  def test_should_raise_exception_if_transitioning_from_unknown_state
    assert_raise(PluginAWeek::Has::States::StateNotActive) {@event.transition_to :off, :from => :invalid_state}
  end
  
  def test_should_raise_exception_if_transitioning_from_inactive_state
    Switch.active_states.delete(:off)
    assert_raise(PluginAWeek::Has::States::StateNotActive) {@event.transition_to :on, :from => :off}
  end
  
  def test_should_raise_exception_if_using_invalid_transition_option
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
    switch = Switch.new
    assert !@event.fire(switch)
  end
  
  def test_should_not_change_state_if_not_fired
    switch = Switch.new
    switch.state = states(:switch_on)
    original_state = switch.state
    
    @event.transition_to :on, :from => :off
    @event.fire(switch)
    
    assert_not_nil switch.state
    assert_same original_state, switch.state
  end
  
  def test_should_not_record_state_change_if_not_fired
    switch = Switch.new
    @event.fire(switch)
    
    assert_nil switch.recorded_event
    assert_nil switch.recorded_from_state
    assert_nil switch.recorded_to_state
  end
  
  def test_should_not_invoke_callbacks_if_not_fired
    switch = Switch.new
    @event.fire(switch)
    
    assert switch.callbacks.empty?
  end
  
  def test_should_return_true_if_fired
    model = Switch.new
    model.state = states(:switch_off)
    @event.transition_to :on, :from => :off
    
    assert @event.fire(model)
  end
  
  def test_should_change_state_if_fired
    model = Switch.new
    model.state = states(:switch_off)
    original_state = model.state
    
    @event.transition_to :on, :from => :off
    @event.fire(model)
    
    assert_not_equal original_state.id, model.state_id
    assert_equal states(:switch_on).id, model.state_id
  end
  
  def test_should_record_state_change_if_fired
    model = Switch.new
    model.state = states(:switch_off)
    
    @event.transition_to :on, :from => :off
    @event.fire(model)
    
    assert_equal @event.record, model.recorded_event
    assert_equal states(:switch_off), model.recorded_from_state
    assert_equal states(:switch_on), model.recorded_to_state
  end
  
  def test_should_invoke_callbacks_if_fired
    model = Switch.new
    model.state = states(:switch_off)
    
    @event.transition_to :on, :from => :off
    @event.fire(model)
    
    expected_callbacks = %w(before_turn_on before_exit_off before_enter_on after_exit_off after_enter_on after_turn_on)
    assert_equal expected_callbacks, model.callbacks
  end
  
  def test_should_invoke_custom_callbacks_if_fired
    model = Switch.new
    model.state = states(:switch_off)
    
    @event.transition_to :on, :from => :off
    @event.callbacks[:before] << :turn_key
    @event.callbacks[:after] << :remove_key
    @event.fire(model)
    
    expected_callbacks = %w(turn_key before_turn_on before_exit_off before_enter_on after_exit_off after_enter_on remove_key after_turn_on)
    assert_equal expected_callbacks, model.callbacks
  end
  
  def test_should_fail_if_after_callback_returns_false
    model = Switch.new
    model.state = states(:switch_off)
    
    @event.transition_to :on, :from => :off
    @event.callbacks[:after] << :after_turn_on
    @event.callbacks[:after] << :return_false
    
    assert !@event.fire(model)
  end
  
  def test_should_fail_if_before_callback_returns_false
    model = Switch.new
    model.state = states(:switch_off)
    
    @event.transition_to :on, :from => :off
    @event.callbacks[:before] << :before_turn_on
    @event.callbacks[:before] << :return_false
    
    assert !@event.fire(model)
  end
  
  def teardown
    (Switch.instance_methods - @original_instance_methods).each do |method|
      Switch.send(:undef_method, method)
    end
  end
  
  private
  def create_transition(from_state_name, to_state_name)
    PluginAWeek::Has::States::StateTransition.new(Switch.active_states[from_state_name], Switch.active_states[to_state_name], {})
  end
end