require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class InvalidEventTest < Test::Unit::TestCase
  def test_should_exist
    assert_not_nil StateMachine::InvalidEvent
  end
end
