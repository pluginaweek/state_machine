require File.dirname(__FILE__) + '/../test_helper'

class NoInitialStateTest < Test::Unit::TestCase
  def test_existence
    assert_not_nil PluginAWeek::Acts::StateMachine::NoInitialState
  end
end