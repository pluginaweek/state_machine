require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AssertionsTest < Test::Unit::TestCase
  include StateMachine::Assertions
  
  def test_should_not_raise_exception_if_key_is_valid
    assert_nothing_raised { assert_valid_keys({:name => 'foo', :value => 'bar'}, :name, :value, :force) }
  end
  
  def test_should_raise_exception_if_key_is_invalid
    exception = assert_raise(ArgumentError) { assert_valid_keys({:name => 'foo', :value => 'bar', :invalid => true}, :name, :value, :force) }
    assert_match 'Invalid key(s): invalid', exception.message
  end
end
