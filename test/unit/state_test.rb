require File.dirname(__FILE__) + '/../test_helper'

class StateTest < Test::Unit::TestCase
  fixtures :state_changes, :state_deadlines
  
  def valid_state
    states(:valid)
  end
  
  def test_no_name
    assert_invalid valid_state, 'name', nil
  end
  
  def test_no_long_description
    assert_invalid valid_state, 'long_description', nil
  end
  
  def test_symbolic_name
    assert_equal :valid, valid_state.name
  end
  
  def test_no_short_description
    assert_equal 'Valid', valid_state.short_description
  end
  
  def test_custom_short_description
    state = valid_state
    state.short_description = 'valid'
    assert_equal 'valid', state.short_description
  end
  
  def test_state_class
    assert_not_nil Vehicle::State
  end
  
  def test_subclassed_state
    assert_not_equal Car::State, Vehicle::State
  end
  
  def test_stored_changes
    state = states(:switch_on)
    expected = [
      state_changes(:light_turned_on),
      state_changes(:light_turned_on_again)
    ]
    
    assert_equal expected, state.changes
  end
  
  def test_stored_deadlines
    state = states(:vehicle_stalled)
    assert_equal [state_deadlines(:vehicle_stalled)], state.deadlines
  end
  
  def test_change_types
    state = Vehicle::State.new
    
    assert_raise(ActiveRecord::AssociationTypeMismatch) {state.changes << StateChange.new}
    assert_nothing_raised {state.changes << Vehicle::StateChange.new}
  end
  
  def test_change_types_for_subclass
    state = Car::State.new
    
    assert_raise(ActiveRecord::AssociationTypeMismatch) {state.changes << StateChange.new}
    assert_raise(ActiveRecord::AssociationTypeMismatch) {state.changes << Vehicle::StateChange.new}
    assert_nothing_raised {state.changes << Car::StateChange.new}
  end
  
  def test_deadline_types
    state = Vehicle::State.new
    
    assert_raise(ActiveRecord::AssociationTypeMismatch) {state.deadlines << StateDeadline.new}
    assert_nothing_raised {state.deadlines << Vehicle::StateDeadline.new}
  end
  
  def test_deadline_types_for_subclass
    state = Car::State.new
    
    assert_raise(ActiveRecord::AssociationTypeMismatch) {state.deadlines << StateDeadline.new}
    assert_raise(ActiveRecord::AssociationTypeMismatch) {state.deadlines << Vehicle::StateDeadline.new}
    assert_nothing_raised {state.deadlines << Car::StateDeadline.new}
  end
end