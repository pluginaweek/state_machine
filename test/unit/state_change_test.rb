require File.dirname(__FILE__) + '/../test_helper'

class StateChangeTest < Test::Unit::TestCase
  fixtures :state_changes, :projects, :vehicles
  
  def test_should_be_valid
    assert_valid state_changes(:rss_reader_design)
  end
  
  def test_should_require_stateful_id
    assert_invalid state_changes(:rss_reader_design), 'stateful_id', nil
  end
  
  def test_should_require_stateful_type
    assert_invalid state_changes(:rss_reader_design), 'stateful_type', nil
  end
  
  def test_should_require_to_state_id
    assert_invalid state_changes(:rss_reader_design), 'to_state_id', nil
  end
  
  def test_should_not_require_event_id
    assert_valid state_changes(:rss_reader_design), 'event_id', nil
  end
  
  def test_should_not_require_from_state_id
    assert_valid state_changes(:rss_reader_design), 'from_state_id', nil
  end
  
  def test_should_automatically_set_occurred_at_when_created
    state_change = StateChange.new
    state_change.stateful = vehicles(:parked)
    state_change.from_state = states(:vehicle_parked)
    state_change.to_state = states(:vehicle_idling)
    state_change.event = events(:vehicle_ignite)
    
    assert_nil state_change.occurred_at
    assert state_change.save!
    assert_not_nil state_change.occurred_at
  end
  
  def test_should_not_have_associated_event_for_initial_state_change
    assert_nil state_changes(:rss_reader_requirements).event
  end
  
  def test_should_have_associated_event_for_full_state_change
    assert_equal events(:project_design), state_changes(:rss_reader_design).event
  end
  
  def test_should_not_have_associated_from_state_for_initial_state_change
    assert_nil state_changes(:rss_reader_requirements).from_state
  end
  
  def test_should_have_associated_from_state_for_full_state_change
    assert_equal states(:project_requirements), state_changes(:rss_reader_design).from_state
  end
  
  def test_should_have_associated_to_state
    assert_equal states(:project_requirements), state_changes(:rss_reader_requirements).to_state
  end
  
  def test_should_have_associated_stateful_model
    assert_equal projects(:rss_reader), state_changes(:rss_reader_requirements).stateful
  end
end