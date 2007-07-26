require File.dirname(__FILE__) + '/../test_helper'

class StateTest < Test::Unit::TestCase
  fixtures :state_changes
  
  def test_should_be_valid
    assert_valid states(:switch_on)
  end
  
  def test_should_require_name
    assert_invalid states(:switch_on), :name, nil
  end
  
  def test_should_require_unique_name
    assert_invalid states(:switch_on).clone, :name
  end
  
  def test_should_have_changes_from_association
    state = states(:project_requirements)
    expected = [
      state_changes(:rss_reader_design)
    ]
    
    assert_equal expected, state.changes_from
  end
  
  def test_should_have_changes_to_association
    state = states(:project_requirements)
    expected = [
      state_changes(:rss_reader_requirements),
      state_changes(:rss_reader_requirements_again)
    ]
    
    assert_equal expected, state.changes_to
  end
  
  def test_should_use_name_as_default_human_name
    state = State.new(:name => 'test')
    assert_equal 'Test', state.human_name
  end
  
  def test_should_use_custom_human_name_if_specified
    state = State.new(:name => 'test', :human_name => 'Custom')
    assert_equal 'Custom', state.human_name
  end
  
  def test_should_convert_to_symbol
    assert_equal :on, states(:switch_on).to_sym
  end
end