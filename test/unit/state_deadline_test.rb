require File.dirname(__FILE__) + '/../test_helper'

class StateDeadlineTest < Test::Unit::TestCase
  fixtures :state_deadlines, :vehicles
  
  def setup
    @vehicle_stalled = state_deadlines(:vehicle_stalled)
  end
  
  def valid_state_deadline
    state_deadlines(:valid)
  end
  
  def test_no_state_id
    assert_invalid valid_state_deadline, 'state_id', nil
  end
  
  def test_no_stateful_id
    assert_invalid valid_state_deadline, 'stateful_id', nil
  end
  
  def test_state_deadline_class
    assert_not_nil Vehicle::StateDeadline
  end
  
  def test_subclassed_state_deadline_class
    assert_not_equal Car::StateDeadline, Vehicle::StateDeadline
  end
  
  def test_state_type
    deadline = Vehicle::StateDeadline.new
    
    assert_raise(ActiveRecord::AssociationTypeMismatch) {deadline.state = State.new}
    assert_nothing_raised {deadline.state = Vehicle::State.new}
  end
  
  def test_state_type_for_subclass
    deadline = Car::StateDeadline.new
    
    assert_raise(ActiveRecord::AssociationTypeMismatch) {deadline.state = State.new}
    assert_nothing_raised {deadline.state = Vehicle::State.new}
    assert_nothing_raised {deadline.state = Car::State.new}
  end
  
  def test_stateful
    assert_not_nil @vehicle_stalled.stateful
    assert_instance_of Vehicle, @vehicle_stalled.stateful
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@vehicle_stalled.stateful = State.new}
    assert_nothing_raised {@vehicle_stalled.stateful = Vehicle.new}
  end
  
  def test_aliased_stateful
    assert_equal @vehicle_stalled.vehicle, @vehicle_stalled.stateful
  end
  
  def test_aliased_stateful_id
    assert_equal @vehicle_stalled.vehicle_id, @vehicle_stalled.stateful_id
  end
end