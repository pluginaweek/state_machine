require File.dirname(__FILE__) + '/../test_helper'

class StateChangeTest < Test::Unit::TestCase
  fixtures :state_changes, :switches
  
  def setup
    @switch_turned_on = state_changes(:light_turned_on)
    @vehicle_state_change = Vehicle::StateChange.new
    @car_state_change = Car::StateChange.new
  end
  
  def valid_state_change
    state_changes(:valid)
  end
  
  def test_no_event_id
    assert_invalid valid_state_change, 'event_id', nil
  end
  
  def test_no_stateful_id
    assert_invalid valid_state_change, 'stateful_id', nil
  end
  
  def test_no_to_state_id
    assert_invalid valid_state_change, 'to_state_id', nil
  end
  
  def test_state_change_class
    assert_not_nil Vehicle::StateChange
  end
  
  def test_subclasses_state_change_class
    assert_not_equal Car::StateChange, Vehicle::StateChange
  end
  
  def test_event_type
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@vehicle_state_change.event = Event.new}
    assert_nothing_raised {@vehicle_state_change.event = Vehicle::Event.new}
  end
  
  def test_event_type_for_subclass
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@car_state_change.event = Event.new}
    assert_nothing_raised {@car_state_change.event = Vehicle::Event.new}
    assert_nothing_raised {@car_state_change.event = Car::Event.new}
  end
  
  def test_from_state_type
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@vehicle_state_change.from_state = State.new}
    assert_nothing_raised {@vehicle_state_change.from_state = Vehicle::State.new}
  end
  
  def test_from_state_type_for_subclass
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@car_state_change.from_state = State.new}
    assert_nothing_raised {@car_state_change.from_state = Vehicle::State.new}
    assert_nothing_raised {@car_state_change.from_state = Car::State.new}
  end
  
  def test_to_state_type
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@vehicle_state_change.to_state = State.new}
    assert_nothing_raised {@vehicle_state_change.to_state = Vehicle::State.new}
  end
  
  def test_to_state_type_for_subclass
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@car_state_change.to_state = State.new}
    assert_nothing_raised {@car_state_change.to_state = Vehicle::State.new}
    assert_nothing_raised {@car_state_change.to_state = Car::State.new}
  end
  
  def test_stateful
    assert_not_nil @switch_turned_on.stateful
    assert_instance_of Switch, @switch_turned_on.stateful
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@switch_turned_on.stateful = State.new}
    assert_nothing_raised {@switch_turned_on.stateful = Switch.new}
  end
  
  def test_aliased_stateful
    assert_equal @switch_turned_on.switch, @switch_turned_on.stateful
  end
  
  def test_aliased_stateful_id
    assert_equal @switch_turned_on.switch_id, @switch_turned_on.stateful_id
  end
end