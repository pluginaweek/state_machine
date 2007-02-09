require File.dirname(__FILE__) + '/../test_helper'

class StateDeadlineTest < Test::Unit::TestCase
  fixtures :state_deadlines, :projects
  
  def valid_state_deadline
    state_deadlines(:valid)
  end
  
  def test_valid_state_deadline
    assert_valid valid_state_deadline
  end
  
  def test_no_state_id
    assert_invalid valid_state_deadline, 'state_id', nil
  end
  
  def test_no_stateful_id
    assert_invalid valid_state_deadline, 'stateful_id', nil
  end
  
  def test_no_stateful_type
    assert_invalid valid_state_deadline, 'stateful_type', nil
  end
  
  def test_state
    assert_equal states(:project_requirements), state_deadlines(:rss_reader_requirements).state
  end
  
  def test_stateful
    assert_equal projects(:rss_reader), state_deadlines(:rss_reader_requirements).stateful
  end
  
  def test_passed
    deadline = StateDeadline.new
    deadline.deadline = Time.now
    assert deadline.passed?
    
    deadline.deadline = 1.second.ago
    assert deadline.passed?
    
    deadline.deadline = 1.month.ago
    assert deadline.passed?
  end
  
  def test_not_passed
    deadline = StateDeadline.new
    deadline.deadline = 1.second.from_now
    assert !deadline.passed?
    
    deadline.deadline = 1.month.from_now
    assert !deadline.passed?
  end
end