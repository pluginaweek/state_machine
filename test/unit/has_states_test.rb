require File.dirname(__FILE__) + '/../test_helper'

class HasStatesTest < Test::Unit::TestCase
  fixtures :switches, :highways, :auto_shops, :vehicles, :state_changes
  
  def setup
    Vehicle.class_eval do
      class << self
        public  :state,
                :event
      end
    end
  end
  
  def test_should_raise_exception_with_invalid_option
    options = {:invalid_option => true}
    assert_raise(ArgumentError) {Message.has_states(options)}
  end
  
  def test_should_raise_exception_if_no_initial_state_given
    assert_raise(PluginAWeek::Has::States::NoInitialState) {Message.has_states({})}
  end
  
  def test_should_allow_subclasses_to_override_initial_state
    assert_equal :idling, Motorcycle.read_inheritable_attribute(:initial_state)
    assert_not_equal Motorcycle.read_inheritable_attribute(:initial_state), Vehicle.read_inheritable_attribute(:initial_state)
  end
  
  def test_active_states_should_be_initially_empty
    expected = {}
    assert_equal expected, Message.active_states
  end
  
  def test_active_events_should_be_initially_empty
    expected = {}
    assert_equal expected, Message.active_events
  end
  
  def test_should_set_initial_state_name_to_initial_option
    assert_equal :dummy, Message.read_inheritable_attribute(:initial_state_name)
  end
  
  def test_should_record_state_changes_by_default
    assert Message.record_state_changes
  end
  
  def test_should_not_record_state_changes_if_specified_not_to
    assert !Switch.record_state_changes
  end
  
  def test_should_create_state_extension
    assert_not_nil Vehicle::StateExtension
  end
  
  def test_should_create_class_level_states_association
    expected = [
      :parked,
      :idling,
      :first_gear,
      :second_gear,
      :third_gear,
      :stalled,
      :inactive
    ].collect! {|state| states(:"vehicle_#{state}")}
    
    assert_equal expected, Vehicle.states
    assert_equal expected, Motorcycle.states
  end
  
  def test_class_states_should_include_superclass_states
    expected = [
      :parked,
      :idling,
      :first_gear,
      :second_gear,
      :third_gear,
      :stalled,
      :inactive
    ].collect! {|state| states(:"vehicle_#{state}")} + [
      :backing_up
    ].collect! {|state| states(:"car_#{state}")}
    
    assert_equal expected, Car.states
  end
  
  def test_should_create_class_level_events_association
    expected = [
      :park,
      :ignite,
      :idle,
      :shift_up,
      :shift_down,
      :crash,
      :repair,
      :inactive
    ].collect! {|event| events(:"vehicle_#{event}")}
    
    assert_equal expected, Vehicle.events
    assert_equal expected, Motorcycle.events
  end
  
  def test_class_events_should_include_superclass_events
    expected = [
      :park,
      :ignite,
      :idle,
      :shift_up,
      :shift_down,
      :crash,
      :repair,
      :inactive
    ].collect! {|event| events(:"vehicle_#{event}")} + [
      :reverse
    ].collect! {|event| events(:"car_#{event}")}
    
    assert_equal expected, Car.events
  end
  
  def test_should_create_class_level_state_changes_association_if_recording_changes
    expected = [
      :parked_parked,
      :idling_parked,
      :idling_idling,
      :first_gear_parked,
      :first_gear_idling,
      :first_gear_first_gear,
      :first_gear_2_parked,
      :first_gear_2_idling,
      :first_gear_2_first_gear,
      :first_gear_2_second_gear,
      :first_gear_2_first_gear_again,
      :stalled_idling,
      :stalled_first_gear,
      :stalled_stalled
    ].collect! {|state_change| state_changes(:"vehicle_#{state_change}")}
    
    assert_equal expected, Vehicle.state_changes
    assert_equal expected, Car.state_changes
  end
  
  def test_should_not_create_class_level_state_changes_association_if_not_recording_changes
    assert !Switch.respond_to?(:state_changes)
  end
  
  def test_should_create_stateful_association_in_state_class
    state = states(:vehicle_first_gear)
    assert_equal 2, state.vehicles.size
    assert ([vehicles(:first_gear), vehicles(:first_gear_2)] - state.vehicles).empty?
  end
  
  def test_should_create_state_association_for_model
    assert_equal states(:vehicle_parked), vehicles(:parked).state
  end
  
  def test_should_create_state_changes_association_for_model_if_recording_changes
    expected = [
      state_changes(:vehicle_idling_parked),
      state_changes(:vehicle_idling_idling)
    ]
    assert_equal expected, vehicles(:idling).state_changes
  end
  
  def test_should_not_create_state_changes_association_for_model_if_not_recording_changes
    assert !switches(:light).respond_to?(:state_changes)
  end
  
  def test_should_clone_active_events_for_subclasses
    Vehicle.active_events.each do |name, vehicle_event|
      car_event = Car.active_events[name]
      assert_not_equal car_event.object_id, vehicle_event.object_id
    end
  end
  
  def test_should_change_cloned_active_event_owner_type_to_subclass_name
    Vehicle.active_events.each do |name, vehicle_event|
      car_event = Car.active_events[name]
      assert_not_equal car_event.object_id, vehicle_event.object_id
    end
  end
  
  def test_should_create_different_state_extension_for_subclasses
    assert_not_equal Vehicle::StateExtension, Car::StateExtension
    assert_not_equal Vehicle::StateExtension, Motorcycle::StateExtension
  end
  
  def test_should_include_superclass_state_extension_methods_in_subclass_extension
    assert (Vehicle::StateExtension.instance_methods - Car::StateExtension.instance_methods).empty?
  end
  
  def test_stringified_active_state_should_be_active
    assert Vehicle.active_state?('parked')
  end
  
  def test_symbolized_active_state_should_be_active
    assert Vehicle.active_state?(:parked)
  end
  
  def test_stringified_inactive_state_should_not_be_active
    assert !Vehicle.active_state?('inactive')
  end
  
  def test_symbolized_inactive_state_should_not_be_active
    assert !Vehicle.active_state?(:inactive)
  end
  
  def test_invalid_state_should_not_be_active
    assert !Vehicle.active_state?(:invalid)
  end
  
  def test_find_first_in_states
    assert_equal nil, Vehicle.find_in_states(:first, :second_gear)
    assert_equal vehicles(:parked), Vehicle.find_in_states(:first, :parked)
  end
  
  def test_find_all_in_states
    assert_equal [], Vehicle.find_in_states(:all, :second_gear)
    assert_equal [vehicles(:first_gear), vehicles(:first_gear_2)], Vehicle.find_in_states(:all, :first_gear)
  end
  
  def test_find_in_states_with_multiple_states
    expected = [
      vehicles(:parked),
      vehicles(:idling)
    ]
    assert_equal expected, Vehicle.find_in_states(:all, :parked, :idling)
  end
  
  def test_find_in_states_with_additional_configuration_options
    expected = [
      vehicles(:idling),
      vehicles(:parked)
    ]
    assert_equal expected, Vehicle.find_in_states(:all, :parked, :idling, :order => 'vehicles.id DESC')
  end
  
  def test_find_in_state_should_be_same_as_find_in_states
    assert_equal [], Vehicle.find_in_state(:all, :second_gear)
    assert_equal [vehicles(:parked)], Vehicle.find_in_state(:all, :parked)
  end
  
  def test_count_in_state_should_find_none_for_invalid_state
    assert_equal 0, Vehicle.count_in_states(:invalid_state)
  end
  
  def test_count_in_states_should_for_none_if_no_records_in_state
    assert_equal 0, Vehicle.count_in_states(:second_gear)
  end
  
  def test_count_in_states_should_find_records_with_state
    assert_equal 1, Vehicle.count_in_states(:parked)
  end
  
  def test_count_in_states_should_finds_records_in_multiple_states
    assert_equal 3, Vehicle.count_in_states(:parked, :first_gear)
  end
  
  def test_calculate_in_states_with_single_state
    assert_equal 100.00, Vehicle.calculate_in_states(:sum, :insurance_premium, :parked)
  end
  
  def test_calculate_in_states_with_multiple_states
    assert_equal 200.00, Vehicle.calculate_in_states(:sum, :insurance_premium, :parked, :idling)
  end
  
  def test_stringified_active_event_should_be_active
    assert Vehicle.active_event?('park')
  end
  
  def test_symbolized_active_event_should_be_active
    assert Vehicle.active_event?(:park)
  end
  
  def test_stringified_inactive_event_should_not_be_active
    assert !Vehicle.active_event?('inactive')
  end
  
  def test_symbolized_inactive_event_should_not_be_active
    assert !Vehicle.active_event?(:inactive)
  end
  
  def test_invalid_event_should_not_be_active
    assert !Vehicle.active_event?(:invalid)
  end
  
  # State method generation testing
  
  def test_should_raise_exception_if_invalid_state_created
    assert_raise(PluginAWeek::Has::States::StateNotFound) {Vehicle.state(:invalid_state)}
  end
  
  def test_should_create_predicate_method_for_each_state
    Vehicle.active_states.keys.each do |state_name|
      assert Vehicle.instance_methods.include?("#{state_name}?")
    end
  end
  
  def test_state_predicate_should_return_true_if_in_state
    vehicle = vehicles(:parked)
    assert vehicle.parked?
  end
  
  def test_state_predicate_should_return_false_if_not_in_state
    vehicle = vehicles(:parked)
    (Vehicle.active_states.keys - [:parked]).each do |state|
      assert !vehicle.send("#{state}?")
    end
  end
  
  def test_should_create_state_change_accessor_for_each_state_if_recording_changes
    Vehicle.active_states.keys.each do |state_name|
      assert Vehicle.instance_methods.include?("#{state_name}_at")
    end
  end
  
  def test_should_not_create_state_change_accessor_for_each_state_if_not_recording_changes
    Switch.active_states.keys.each do |state_name|
      assert !Switch.instance_methods.include?("#{state_name}_at")
    end
  end
  
  def test_should_not_have_state_change_if_state_was_never_transitioned_to
    vehicle = vehicles(:first_gear)
    
    [
      :second_gear,
      :third_gear,
      :stalled
    ].each do |state|
      assert_nil vehicle.send("#{state}_at", :first)
      assert_nil vehicle.send("#{state}_at", :last)
      assert_equal [], vehicle.send("#{state}_at", :all)
    end
  end
  
  def test_should_have_state_change_if_state_was_transitioned_to
    vehicle = vehicles(:first_gear)
    
    [
      :parked,
      :idling,
      :first_gear
    ].each do |state|
      occurred_at = state_changes("vehicle_first_gear_#{state}").occurred_at
      assert_equal occurred_at, vehicle.send("#{state}_at", :first)
      assert_equal occurred_at, vehicle.send("#{state}_at", :last)
      assert_equal [occurred_at], vehicle.send("#{state}_at", :all)
    end
  end
  
  def test_should_return_last_state_change_by_default
    assert_equal state_changes(:vehicle_first_gear_2_first_gear_again).occurred_at, vehicles(:first_gear_2).first_gear_at
  end
  
  def test_should_return_first_state_change_if_first_specified
    assert_equal state_changes(:vehicle_first_gear_2_first_gear).occurred_at, vehicles(:first_gear_2).first_gear_at(:first)
  end
  
  def test_should_return_all_state_changes_if_all_specified
    expected = [
      state_changes(:vehicle_first_gear_2_first_gear).occurred_at,
      state_changes(:vehicle_first_gear_2_first_gear_again).occurred_at
    ]
    assert_equal expected, vehicles(:first_gear_2).first_gear_at(:all)
  end
  
  def test_should_create_callbacks_for_each_state
    Vehicle.active_states.keys.each do |state_name|
      [:before_enter, :after_enter, :before_exit, :after_exit].each do |callback|
        assert Vehicle.singleton_methods.include?("#{callback}_#{state_name}")
      end
    end
  end
  
  def test_should_include_callback_from_options
    assert_equal [:put_on_seatbelt], Vehicle.read_inheritable_attribute(:before_exit_parked)
    assert_equal 1, Vehicle.read_inheritable_attribute(:after_enter_parked).size
    assert_instance_of Proc, Vehicle.read_inheritable_attribute(:after_enter_parked)[0]
  end
  
  # Event method generation testing
  
  def test_should_raise_exception_if_invalid_event_created
    assert_raise(PluginAWeek::Has::States::EventNotFound) {Vehicle.event(:invalid_event)}
  end
  
  def test_should_create_event_action_method_for_each_event
    Vehicle.active_events.keys.each do |event_name|
      assert Vehicle.instance_methods.include?("#{event_name}!")
    end
  end
  
  def test_should_create_event_callback_method_for_each_event
    Vehicle.active_events.keys.each do |event_name|
      assert Vehicle.singleton_methods.include?("after_#{event_name}")
    end
  end
  
  def test_should_save_record_before_execute_event_on_new_record
    vehicle = Vehicle.new
    
    assert vehicle.ignite!
    assert !vehicle.new_record?
    assert_equal 2, vehicle.state_changes.size
  end
  
  uses_transaction :test_should_not_save_record_if_executed_event_fails_on_new_record
  def test_should_not_save_record_if_executed_event_fails_on_new_record
    vehicle = Vehicle.new
    
    assert !vehicle.shift_up!
#    assert vehicle.new_record? # See #9105
    assert_raise(ActiveRecord::RecordNotFound) {Vehicle.find(vehicle.id)}
    assert_equal 5, Vehicle.count
  end
  
  def test_should_not_allow_event_execution_if_no_transition_available
    vehicle = vehicles(:parked)
    
    [
      :park,
      :idle,
      :shift_up,
      :shift_down,
      :crash,
      :repair
    ].each do |event|
      assert !vehicle.send("#{event}!")
    end
  end
  
  uses_transaction :test_should_raise_exception_and_rollback_if_event_called_on_invalid_record
  def test_should_raise_exception_and_rollback_if_event_called_on_invalid_record
    vehicle = vehicles(:parked)
    vehicle.highway_id = nil
    
    assert_raise(ActiveRecord::RecordInvalid) {vehicle.ignite!}
    vehicle.reload
    assert_equal states(:vehicle_parked), vehicle.state
    assert_equal [state_changes(:vehicle_parked_parked)], vehicle.state_changes
  end
  
  # Instance method testing
  
  def test_should_be_able_to_use_symbol_for_initial_state_name
    Message.write_inheritable_attribute(:initial_state_name, :dummy)
    assert_equal :dummy, Message.new.initial_state_name
  end
  
  def test_should_evaluate_procs_for_dynamic_initial_state_names
    Message.write_inheritable_attribute(:initial_state_name, Proc.new {|machine| :dummy})
    assert_equal :dummy, Message.new.initial_state_name
  ensure
    Message.write_inheritable_attribute(:initial_state_name, :dummy)
  end
  
  def test_should_use_initial_state_name_for_initial_state
    assert_equal states(:vehicle_parked), Vehicle.new.initial_state
  end
  
  def test_should_use_dynamic_proc_to_determine_initial_state
    vehicle = Vehicle.new
    vehicle.force_idle = true
    
    assert_equal states(:vehicle_idling), vehicle.initial_state
  end
  
  def test_should_set_initial_state_for_new_record_before_being_saved
    assert_equal states(:vehicle_parked), Vehicle.new.state
  end
  
  def test_should_use_current_state_for_existing_record
    assert_equal states(:vehicle_idling), vehicles(:idling).state
  end
  
  def test_should_use_initial_state_id_for_new_record_before_being_saved
    assert_equal states(:vehicle_parked).id, Vehicle.new.state_id
  end
  
  def test_should_use_current_state_id_for_existing_record
    assert_equal states(:vehicle_idling).id, vehicles(:idling).state_id
  end
  
  def test_next_state_should_raise_exception_for_invalid_event_name
    vehicle = vehicles(:idling)
    assert_raise(PluginAWeek::Has::States::StateNotActive) {vehicle.next_state_for_event(:invalid_name)}
  end
  
  def test_next_state_should_raise_exception_for_inactive_event_name
    vehicle = vehicles(:idling)
    assert_raise(PluginAWeek::Has::States::StateNotActive) {vehicle.next_state_for_event(:inactive)}
  end
  
  def test_next_state_should_return_nil_if_no_next_state_found
    vehicle = vehicles(:idling)
    assert_nil vehicle.next_state_for_event(:ignite)
  end
  
  def test_next_state_should_return_first_next_state_if_next_state_found
    vehicle = vehicles(:idling)
    assert_equal states(:vehicle_parked), vehicle.next_state_for_event(:park)
  end
  
  def test_next_states_should_raise_exception_for_invalid_event_name
    vehicle = vehicles(:idling)
    assert_raise(PluginAWeek::Has::States::StateNotActive) {vehicle.next_states_for_event(:invalid_name)}
  end
  
  def test_next_states_should_raise_exception_for_inactive_event_name
    vehicle = vehicles(:idling)
    assert_raise(PluginAWeek::Has::States::StateNotActive) {vehicle.next_states_for_event(:inactive)}
  end
  
  def test_next_states_should_be_empty_if_no_next_states_found
    vehicle = vehicles(:idling)
    assert_equal [], vehicle.next_states_for_event(:ignite)
  end
  
  def test_next_states_should_return_all_next_states_if_next_states_found
    vehicle = vehicles(:idling)
    assert_equal [states(:vehicle_parked)], vehicle.next_states_for_event(:park)
  end
  
  def test_should_not_record_state_change_if_not_option_disabled
    switch = switches(:light)
    switch.send(:record_state_change, nil, states(:switch_off), states(:switch_on))
    
    assert_nil StateChange.find_by_stateful_type('Switch')
  end
  
  def test_should_record_state_change_with_no_event
    vehicle = vehicles(:idling)
    vehicle.send(:record_state_change, nil, states(:vehicle_idling), states(:vehicle_first_gear))
    
    assert_equal 3, vehicle.state_changes.size
    
    state_change = vehicle.state_changes.last
    assert_nil state_change.event
    assert_equal states(:vehicle_idling), state_change.from_state
    assert_equal states(:vehicle_first_gear), state_change.to_state
  end
  
  def test_record_state_change_with_no_from_state
    vehicle = vehicles(:idling)
    vehicle.send(:record_state_change, events(:vehicle_shift_up), nil, states(:vehicle_second_gear))
    
    assert_equal 3, vehicle.state_changes.size
    
    state_change = vehicle.state_changes.last
    assert_equal events(:vehicle_shift_up), state_change.event
    assert_nil state_change.from_state
    assert_equal states(:vehicle_second_gear), state_change.to_state
  end
  
  # Go through some state machine scenarios
  
  def test_crash_if_shop_available
    v = vehicles(:first_gear)
    assert v.auto_shop.available?
    assert_equal 0, v.auto_shop.num_customers
    assert v.crash!
    assert v.auto_shop.busy?
    assert_equal 1, v.auto_shop.num_customers
    assert_equal 200.00, v.insurance_premium
  end
  
  def test_no_crash_if_shop_unavailable
    v = vehicles(:first_gear)
    assert v.auto_shop.available?
    assert v.auto_shop.tow_vehicle!
    assert v.auto_shop.busy?
    assert !v.crash!
  end
  
  def test_repair_if_shop_busy
    v = vehicles(:stalled)
    assert v.repair!
    assert v.parked?
    assert v.auto_shop.available?
  end
  
  def test_no_repair_if_shop_available
    v = vehicles(:stalled)
    assert v.auto_shop.fix_vehicle!
    assert v.auto_shop.available?
    assert !v.repair!
  end
  
  def test_event_action_success
    v = vehicles(:parked)
    
    assert v.ignite!
    assert_equal 2, v.state_changes.size
    assert v.seatbelt_on
  end
  
  def test_circular_event_action
    v = vehicles(:stalled)
    
    assert v.stalled?
    assert v.ignite!
    assert v.stalled?
  end
end