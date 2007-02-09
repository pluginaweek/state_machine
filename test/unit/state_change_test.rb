require File.dirname(__FILE__) + '/../test_helper'

class StateChangeTest < Test::Unit::TestCase
  fixtures :state_changes, :projects
  
  def valid_state_change
    state_changes(:valid)
  end
  
  def test_valid_state_change
    assert_valid valid_state_change
  end
  
  def test_no_event_id
    assert_valid valid_state_change, 'event_id', nil
  end
  
  def test_no_stateful_id
    assert_invalid valid_state_change, 'stateful_id', nil
  end
  
  def test_no_stateful_type
    assert_invalid valid_state_change, 'stateful_type', nil
  end
  
  def test_no_to_state_id
    assert_invalid valid_state_change, 'to_state_id', nil
  end
  
  def test_no_from_state_id
    assert_valid valid_state_change, 'from_state_id', nil
  end
  
  def test_no_event
    assert_nil state_changes(:rss_reader_requirements).event
  end
  
  def test_event
    assert_equal events(:project_design), state_changes(:rss_reader_design).event
  end
  
  def test_no_from_state
    assert_nil state_changes(:rss_reader_requirements).from_state
  end
  
  def test_from_state
    assert_equal states(:project_requirements), state_changes(:rss_reader_design).from_state
  end
  
  def test_to_state
    assert_equal states(:project_requirements), state_changes(:rss_reader_requirements).to_state
  end
  
  def test_stateful
    assert_equal projects(:rss_reader), state_changes(:rss_reader_requirements).stateful
  end
end