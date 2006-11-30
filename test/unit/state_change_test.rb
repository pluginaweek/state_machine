require File.dirname(__FILE__) + '/../test_helper'

class StateChangeTest < Test::Unit::TestCase
  fixtures :state_changes, :switches
  
  def setup
    @switch_state_change = state_changes(:light_turned_on)
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
  
  def test_event
    assert_not_nil @switch_state_change.event
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@switch_state_change.event = Event.new}
    assert_nothing_raised {@switch_state_change.event = Switch::Event.new}
  end
  
  def test_from_state
    assert_not_nil @switch_state_change.from_state
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@switch_state_change.from_state = State.new}
    assert_nothing_raised {@switch_state_change.from_state = Switch::State.new}
  end
  
  def test_to_state
    assert_not_nil @switch_state_change.to_state
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@switch_state_change.to_state = State.new}
    assert_nothing_raised {@switch_state_change.to_state = Switch::State.new}
  end
  
  def test_stateful
    assert_not_nil @switch_state_change.stateful
    assert_instance_of Switch, @switch_state_change.stateful
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@switch_state_change.stateful = State.new}
    assert_nothing_raised {@switch_state_change.stateful = Switch.new}
  end
  
  def test_aliased_stateful
    assert_equal @switch_state_change.switch, @switch_state_change.stateful
  end
  
  def test_aliased_stateful_id
    assert_equal @switch_state_change.switch_id, @switch_state_change.stateful_id
  end
end