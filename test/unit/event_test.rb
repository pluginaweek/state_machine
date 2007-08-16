require File.dirname(__FILE__) + '/../test_helper'

class EventTest < Test::Unit::TestCase
  fixtures :state_changes
  
  def test_should_be_valid
    assert_valid events(:switch_turn_on)
  end
  
  def test_should_require_name
    assert_invalid events(:switch_turn_on), :name, nil
  end
  
  def test_should_require_unique_name
    assert_invalid events(:switch_turn_on).clone, :name
  end
  
  def test_should_have_state_changes_association
    event = events(:project_design)
    expected = [
      state_changes(:rss_reader_design)
    ]
    
    assert_equal expected, event.state_changes
  end
  
  def test_should_use_name_as_default_human_name
    event = Event.new(:name => 'test')
    assert_equal 'Test', event.human_name
  end
  
  def test_should_use_custom_human_name_if_specified
    event = Event.new(:name => 'test', :human_name => 'Custom')
    assert_equal 'Custom', event.human_name
  end
  
  def test_should_convert_to_symbol
    assert_equal :turn_on, events(:switch_turn_on).to_sym
  end
end