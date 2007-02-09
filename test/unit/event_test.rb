require File.dirname(__FILE__) + '/../test_helper'

class EventTest < Test::Unit::TestCase
  fixtures :state_changes
  
  def valid_event
    events(:valid)
  end
  
  def test_valid_event
    assert_valid valid_event
  end
  
  def test_no_name
    assert_invalid valid_event, 'name', nil
  end
  
  def test_unique_name
    existing_event = events(:project_elicit_requirements)
    similar_event = existing_event.clone
    similar_event.owner_type = 'Employee'
    
    assert_valid similar_event
    assert_invalid Event.new(:name => 'elicit_requirements', :owner_type => 'Project')
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
  
  def test_stored_changes
    event = events(:project_design)
    expected = [
      state_changes(:rss_reader_design)
    ]
    
    assert_equal expected, event.state_changes
  end
end