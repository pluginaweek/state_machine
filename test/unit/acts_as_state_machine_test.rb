require File.dirname(__FILE__) + '/../test_helper'

class PluginAWeek::Acts::StateMachine::Support::Event
  attr_reader :klass
end

Message.class_eval do
  def self.initial_state_name
    read_inheritable_attribute(:initial_state_name)
  end
end

class ActsAsStateMachineTest < Test::Unit::TestCase
  fixtures :highways, :auto_shops, :vehicles, :state_changes, :state_deadlines
  
  def setup
    @vehicle = Vehicle.new
    @car = Car.new
    @motorcycle = Motorcycle.new
    @auto_shop = AutoShop.new
    
    Vehicle.class_eval do
      class << self
        public  :state,
                :event
      end
      
      public  :record_transition,
              :after_find,
              :check_deadlines,
              :set_initial_state_id
    end
  end
  
  def test_invalid_key
    options = {:invalid_key => true}
    assert_raise(ArgumentError) {Message.acts_as_state_machine(options)}
  end
  
  def test_no_initial_state
    assert_raise(PluginAWeek::Acts::StateMachine::NoInitialState) {Message.acts_as_state_machine({})}
  end
  
  def test_default_valid_states
    expected = {}
    assert_equal expected, Message.valid_states
  end
  
  def test_default_initial_state_name
    assert_equal :dummy, Message.initial_state_name
  end
  
  def test_default_valid_events
    expected = {}
    assert_equal expected, Message.valid_events
  end
  
  def test_default_use_state_deadlines
    assert !Message.use_state_deadlines
  end
  
  def test_state_extension
    assert_not_nil Vehicle::StateExtension
  end
  
  def test_no_deadline_class
    assert !Switch.use_state_deadlines
    assert !Switch.const_defined?('StateDeadline')
  end
  
  def test_states
    expected = [
      :parked,
      :idling,
      :first_gear,
      :second_gear,
      :third_gear,
      :stalled
    ].collect! {|state| states(:"vehicle_#{state}")}
    
    assert_equal expected, Vehicle.states
    assert_equal expected, Motorcycle.states
    
    car_expected = expected + [
      :backing_up
    ].collect! {|state| states(:"car_#{state}")}
    
    assert_equal car_expected, Car.states
  end
  
  def test_events
    expected = [
      :park,
      :ignite,
      :idle,
      :idling_deadline_passed,
      :shift_up,
      :shift_down,
      :crash,
      :repair
    ].collect! {|event| events(:"vehicle_#{event}")}
    
    assert_equal expected, Vehicle.events
    assert_equal expected, Motorcycle.events
    
    car_expected = expected + [
      :reverse
    ].collect! {|event| events(:"car_#{event}")}
    
    assert_equal car_expected, Car.events
  end
  
  def test_state_changes
    expected = [
      :parked_initial,
      :idling_initial,
      :idling_idle,
      :first_gear_initial,
      :first_gear_idle,
      :first_gear_first_gear,
      :first_gear_2_initial,
      :first_gear_2_idle,
      :first_gear_2_first_gear,
      :first_gear_2_second_gear,
      :first_gear_2_first_gear_again,
      :stalled_idle,
      :stalled_first_gear,
      :stalled_stalled
    ].collect! {|state_change| state_changes(:"vehicle_#{state_change}")}
    
    assert_equal expected, Vehicle.state_changes
    assert_equal expected, Car.state_changes
  end
  
  def test_state_deadlines
    expected = [
      :stalled,
      :idling
    ].collect! {|state| state_deadlines(:"vehicle_#{state}")}
    
    assert_equal expected, Vehicle.state_deadlines
    assert_equal expected, Car.state_deadlines
  end
  
  def test_events_not_same_objects
    assert_not_equal Car.valid_events.object_id, Vehicle.valid_events.object_id
    
    Vehicle.valid_events.each do |name, vehicle_event|
      car_event = Car.valid_events[name]
      assert_not_equal car_event.object_id, vehicle_event.object_id
      
      assert_equal Car, car_event.klass
      assert_equal Vehicle, vehicle_event.klass
    end
  end
  
  def test_valid_state_names
    expected = [
      :parked,
      :idling,
      :first_gear,
      :second_gear,
      :third_gear,
      :stalled
    ]
    assert_equal expected.size, Vehicle.valid_state_names.size
    assert_equal [], expected - Vehicle.valid_state_names
  end
  
  def test_valid_state_names_for_subclasses
    shared = [
      :parked,
      :idling,
      :first_gear,
      :second_gear,
      :third_gear,
      :stalled
    ]
    
    car_expected = shared + [
      :backing_up
    ]
    assert_equal car_expected.size, Car.valid_state_names.size
    assert_equal [], car_expected - Car.valid_state_names
    
    assert_equal shared.size, Motorcycle.valid_state_names.size
    assert_equal [], shared - Motorcycle.valid_state_names
  end
  
  def test_find_first_in_states
    assert_equal nil, Vehicle.find_in_states(:first, :second_gear)
    assert_equal vehicles(:valid), Vehicle.find_in_states(:first, :parked)
  end
  
  def test_find_in_state
    assert_equal [], Vehicle.find_in_state(:all, :second_gear)
    assert_equal [vehicles(:valid), vehicles(:parked)], Vehicle.find_in_state(:all, :parked)
  end
  
  def test_find_in_multiple_states
    expected = [
      vehicles(:valid),
      vehicles(:parked),
      vehicles(:idling)
    ]
    assert_equal expected, Vehicle.find_in_states(:all, :parked, :idling)
  end
  
  def test_count_in_states
    assert_equal 0, Vehicle.count_in_states(:invalid_state)
    assert_equal 0, Vehicle.count_in_states(:second_gear)
    assert_equal 2, Vehicle.count_in_states(:parked)
  end
  
  def test_count_in_multiple_states
    assert_equal 4, Vehicle.count_in_states(:parked, :first_gear)
  end
  
  def test_calculate_in_state
    assert_equal 200.00, Vehicle.calculate_in_states(:sum, :insurance_premium, :parked)
  end
  
  def test_calculate_in_multiple_states
    assert_equal 300.00, Vehicle.calculate_in_states(:sum, :insurance_premium, :parked, :idling)
  end
  
  def test_event_names
    expected = [
      :park,
      :ignite,
      :idle,
      :idling_deadline_passed,
      :shift_up,
      :shift_down,
      :crash,
      :repair
    ]
    assert_equal expected.size, Vehicle.valid_event_names.size
    assert_equal [], expected - Vehicle.valid_event_names
  end
  
  def test_event_names_for_subclasses
    shared = [
      :park,
      :ignite,
      :idle,
      :idling_deadline_passed,
      :shift_up,
      :shift_down,
      :crash,
      :repair
    ]
    
    car_expected = shared + [
      :reverse
    ]
    assert_equal car_expected.size, Car.valid_event_names.size
    assert_equal [], car_expected - Car.valid_event_names
    
    assert_equal shared.size, Motorcycle.valid_event_names.size
    assert_equal [], shared - Motorcycle.valid_event_names
  end
  
  def test_invalid_state
    assert_raise(PluginAWeek::Acts::StateMachine::InvalidState) {Vehicle.state(:invalid_state)}
  end
  
  def test_in_state
    vehicle = vehicles(:parked)
    assert vehicle.parked?
    
    [
      :idling,
      :first_gear,
      :second_gear,
      :third_gear,
      :stalled
    ].each do |state|
      assert !vehicle.send("#{state}?")
    end
    
    vehicle = vehicles(:first_gear)
    assert vehicle.first_gear?
    
    [
      :parked,
      :idling,
      :second_gear,
      :third_gear,
      :stalled
    ].each do |state|
      assert !vehicle.send("#{state}?")
    end
  end
  
  def test_state_change_never_occurred
    vehicle = vehicles(:first_gear)
    
    [
      :second_gear,
      :third_gear,
      :stalled
    ].each do |state|
      assert_nil vehicle.send("#{state}_at")
    end
    
    [
      :parked,
      :idling,
      :first_gear
    ].each do |state|
      assert_not_nil vehicle.send("#{state}_at")
    end
  end
  
  def test_state_change_occurred_twice
    assert_equal state_changes(:vehicle_first_gear_2_first_gear_again).occurred_at, vehicles(:first_gear_2).first_gear_at
  end
  
  def test_get_state_deadline
    vehicle = vehicles(:idling)
    assert_equal state_deadlines(:vehicle_idling).deadline, vehicle.idling_deadline
    
    [
      :parked,
      :first_gear,
      :second_gear,
      :third_gear,
      :stalled
    ].each do |state|
      assert_nil vehicle.send("#{state}_deadline")
    end
  end
  
  def test_set_state_deadline
    vehicle = vehicles(:idling)
    state = states(:vehicle_parked)
    
    assert_nil vehicle.state_deadlines.find_by_state_id(state.id)
    vehicle.parked_deadline = Time.now
    assert_not_nil vehicle.state_deadlines.find_by_state_id(state.id)
  end
  
  def test_clear_state_deadline
    vehicle = vehicles(:idling)
    state = states(:vehicle_idling)
    
    assert_not_nil vehicle.idling_deadline
    vehicle.clear_idling_deadline
    assert_nil vehicle.idling_deadline
    assert_nil vehicle.state_deadlines.find_by_state_id(state.id)
  end
  
  def test_deadlined_passed?
    vehicle = vehicles(:idling)
    assert !vehicle.idling_deadline_passed?
    
    vehicle.idling_deadline = 10.days.ago
    assert vehicle.idling_deadline_passed?
  end
  
  def test_find_state_in_association
    highway = highways(:route_66)
    
    expected = [
      vehicles(:valid),
      vehicles(:parked),
      vehicles(:idling),
      vehicles(:first_gear),
      vehicles(:first_gear_2),
      vehicles(:stalled)
    ]
    assert_equal expected, highway.vehicles
    
    assert_equal [vehicles(:idling)], highway.vehicles.idling
    assert_equal [vehicles(:first_gear), vehicles(:first_gear_2)], highway.vehicles.first_gear
  end
  
  def test_count_state_in_association
    highway = highways(:route_66)
    
    assert_equal 0, highway.vehicles.second_gear_count
    assert_equal 1, highway.vehicles.idling_count
    assert_equal 2, highway.vehicles.first_gear_count
  end
  
  def test_invalid_event
    assert_raise(PluginAWeek::Acts::StateMachine::InvalidEvent) {Vehicle.event(:invalid_event)}
  end
  
  def test_event_action_on_new_record
    vehicle = Vehicle.new
    
    assert vehicle.ignite!
    assert !vehicle.new_record?
    assert_equal 2, vehicle.state_changes.size
    assert_equal 0, vehicle.state_deadlines.size
    assert vehicle.seatbelt_on
  end
  
  def test_event_action_failure_on_new_record
    vehicle = Vehicle.new
    
    assert !vehicle.shift_up!
    assert_raise(ActiveRecord::RecordNotFound) {Vehicle.find(vehicle.id)}
    assert_equal 6, Vehicle.count
  end
  
  def test_event_action_no_transition_available
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
  
  def test_event_action_save_failed
    v = vehicles(:parked)
    v.highway_id = nil
    
    assert_raise(ActiveRecord::RecordInvalid) {v.ignite!}
  end
  
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
  
  def test_initial_state_name_as_symbol
    Message.write_inheritable_attribute(:initial_state_name, :dummy)
    assert_equal :dummy, Message.new.initial_state_name
  end
  
  def test_initial_state_name_as_proc
    Message.write_inheritable_attribute(:initial_state_name, Proc.new {|machine| :dummy})
    assert_equal :dummy, Message.new.initial_state_name
  end
  
  def test_initial_state
    assert_equal states(:vehicle_parked), Vehicle.new.initial_state
  end
  
  def test_dynamic_initial_state
    vehicle = Vehicle.new
    vehicle.force_idle = true
    
    assert_equal states(:vehicle_idling), vehicle.initial_state
  end
  
  def test_state_for_new_record
    assert_equal states(:vehicle_parked), Vehicle.new.state
  end
  
  def test_state_for_existing_record
    assert_equal states(:vehicle_idling), vehicles(:idling).state
  end
  
  def test_state_id_for_new_record
    assert_equal states(:vehicle_parked).id, Vehicle.new.state_id
  end
  
  def test_state_id_for_existing_record
    assert_equal states(:vehicle_idling).id, vehicles(:idling).state_id
  end
  
  def test_state_name
    assert_equal :parked, vehicles(:parked).state_name
  end
  
  def test_next_state_for_event_invalid_name
    vehicle = vehicles(:idling)
    assert_raise(PluginAWeek::Acts::StateMachine::InvalidEvent) {vehicle.next_state_for_event(:invalid_name)}
  end
  
  def test_next_state_for_event
    vehicle = vehicles(:idling)
    assert_nil vehicle.next_state_for_event(:shift_down)
    assert_equal :first_gear, vehicle.next_state_for_event(:shift_up)
  end
  
  def test_next_states_for_event
    vehicle = vehicles(:idling)
    assert_equal [], vehicle.next_states_for_event(:shift_down)
    assert_equal [:first_gear], vehicle.next_states_for_event(:shift_up)
  end
  
  def test_record_transition_no_event
    vehicle = vehicles(:idling)
    vehicle.record_transition(nil, :idling, :first_gear)
    
    assert_equal 3, vehicle.state_changes.size
    
    state_change = vehicle.state_changes.last
    assert_nil state_change.event
    assert_equal :idling, state_change.from_state.name
    assert_equal :first_gear, state_change.to_state.name
  end
  
  def test_record_transition_no_from_state
    vehicle = vehicles(:idling)
    vehicle.record_transition(:shift_up, nil, :second_gear)
    
    assert_equal 3, vehicle.state_changes.size
    
    state_change = vehicle.state_changes.last
    assert_equal :shift_up, state_change.event.name
    assert_nil state_change.from_state
    assert_equal :second_gear, state_change.to_state.name
  end
  
  def test_record_transition_with_deadline_cleared
    vehicle = vehicles(:idling)
    assert vehicle.idling_deadline
    
    vehicle.record_transition(:ignite, :parked, :idling)
    assert_nil vehicle.idling_deadline
  end
  
  def test_check_deadlines_no_transition
    vehicle = vehicles(:idling)
    vehicle.update_attribute(:idling_deadline, 10.minutes.from_now)
    assert !vehicle.check_deadlines
  end
  
  def test_check_deadlines_with_transition
    vehicle = vehicles(:idling)
    assert vehicle.idling?
    
    vehicle.update_attribute(:idling_deadline, 10.minutes.ago)
    assert vehicle.check_deadlines
    assert !vehicle.idling?
    assert vehicle.parked?
  end
  
  def test_deadlines_checked_after_find
    vehicle = vehicles(:idling)
    assert vehicle.idling?
    vehicle.update_attribute(:idling_deadline, 10.minutes.ago)
    assert vehicle.idling?
    
    vehicle = Vehicle.find(vehicle.id)
    assert !vehicle.idling?
    assert vehicle.parked?
  end
  
  def test_set_initial_state_id_on_nil
    v = Vehicle.new
    assert v[:state_id].nil?
    
    v.set_initial_state_id
    assert v[:state_id]
  end
  
  def test_set_initial_state_id_already_exists
    v = Vehicle.new
    assert v[:state_id].nil?
    
    v.state_id = 302
    assert v[:state_id]
    
    v.set_initial_state_id
    assert_equal 302, v[:state_id]
  end
end