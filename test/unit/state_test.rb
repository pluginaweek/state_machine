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
  
  def test_state_changes
    state = states(:switch_on)
    expected = [
      state_changes(:light_turned_on),
      state_changes(:light_turned_on_again)
    ]
    
    assert_equal expected, state.changes
  end
  
  def test_state_deadlines
    state = states(:switch_on)
    assert_equal [state_deadlines(:on_deadline)], state.deadlines
  end
end