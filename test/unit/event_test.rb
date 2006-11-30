require File.dirname(__FILE__) + '/../test_helper'

class EventTest < Test::Unit::TestCase
  fixtures :state_changes, :state_deadlines
  
  def valid_event
    events(:valid)
  end
  
  def test_no_name
    assert_invalid valid_event, 'name', nil
  end
  
  def test_no_long_description
    assert_invalid valid_event, 'long_description', nil
  end
  
  def test_symbolic_name
    assert_equal :valid, valid_event.name
  end
  
  def test_no_short_description
    assert_equal 'Valid', valid_event.short_description
  end
  
  def test_custom_short_description
    event = valid_event
    event.short_description = 'valid'
    assert_equal 'valid', event.short_description
  end
  
  def test_event_class
    assert_not_nil Vehicle::Event
  end
  
  def test_subclassed_event_class
    assert_not_equal Car::Event, Vehicle::Event
  end
  
  def test_state_changes
    event = events(:switch_turn_on)
    expected = [
      state_changes(:light_turned_on),
      state_changes(:light_turned_on_again)
    ]
    
    assert_equal expected, event.state_changes
  end
  
  def test_state_change_types
    event = Vehicle::Event.new
    
    assert_raise(ActiveRecord::AssociationTypeMismatch) {event.state_changes << StateChange.new}
    assert_nothing_raised {event.state_changes << Vehicle::StateChange.new}
  end
  
  def test_state_change_types_for_subclass
    event = Car::Event.new
    
    assert_raise(ActiveRecord::AssociationTypeMismatch) {event.state_changes << StateChange.new}
    assert_raise(ActiveRecord::AssociationTypeMismatch) {event.state_changes << Vehicle::StateChange.new}
    assert_nothing_raised {event.state_changes << Car::StateChange.new}
  end
end