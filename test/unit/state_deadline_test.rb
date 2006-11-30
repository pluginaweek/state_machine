require File.dirname(__FILE__) + '/../test_helper'

class StateDeadlineTest < Test::Unit::TestCase
  fixtures :state_deadlines, :switches
  
  def setup
    switches(:light)
    @switch_state_deadline = state_deadlines(:switch_on)
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
  
  def test_state
    assert_not_nil @switch_state_deadline.state
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@switch_state_deadline.state = State.new}
    assert_nothing_raised {@switch_state_deadline.state = Switch::State.new}
  end
  
  def test_stateful
    assert_not_nil @switch_state_deadline.stateful
    assert_instance_of Switch, @switch_state_deadline.stateful
    assert_raise(ActiveRecord::AssociationTypeMismatch) {@switch_state_deadline.stateful = State.new}
    assert_nothing_raised {@switch_state_deadline.stateful = Switch.new}
  end
  
  def test_aliased_stateful
    assert_equal @switch_state_deadline.switch, @switch_state_deadline.stateful
  end
  
  def test_aliased_stateful_id
    assert_equal @switch_state_deadline.switch_id, @switch_state_deadline.stateful_id
  end
end