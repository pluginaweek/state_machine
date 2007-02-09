require File.dirname(__FILE__) + '/../test_helper'

class StateTest < Test::Unit::TestCase
  fixtures :state_changes, :state_deadlines
  
  def valid_state
    states(:valid)
  end
  
  def test_valid_state
    assert_valid valid_state
  end
  
  def test_no_name
    assert_invalid valid_state, 'name', nil
  end
  
  def test_unique_name
    existing_state = states(:project_requirements)
    similar_state = existing_state.clone
    similar_state.owner_type = 'Workflow'
    
    assert_valid similar_state
    assert_invalid State.new(:name => 'requirements', :owner_type => 'Project')
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
  
  def test_stored_changes
    state = states(:project_requirements)
    expected = [
      state_changes(:rss_reader_requirements),
      state_changes(:rss_reader_requirements_again)
    ]
    
    assert_equal expected, state.changes
  end
  
  def test_stored_deadlines
    state = states(:project_requirements)
    assert_equal [state_deadlines(:rss_reader_requirements)], state.deadlines
  end
end