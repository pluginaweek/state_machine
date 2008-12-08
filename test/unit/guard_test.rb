require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class GuardTest < Test::Unit::TestCase
  def setup
    @guard = PluginAWeek::StateMachine::Guard.new(:to => 'on', :from => 'off')
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) { PluginAWeek::StateMachine::Guard.new(:invalid => true) }
  end
  
  def test_should_have_requirements
    expected = {:to => 'on', :from => 'off'}
    assert_equal expected, @guard.requirements
  end
end

class GuardWithNoRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new
  end
  
  def test_should_match_nil_query
    assert @guard.matches?(@object, nil)
  end
  
  def test_should_match_empty_query
    assert @guard.matches?(@object, {})
  end
  
  def test_should_match_non_empty_query
    assert @guard.matches?(@object, :from => 'off', :to => 'on', :on => 'turn_on')
  end
end

class GuardWithToRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:to => 'on')
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :to => 'on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :to => 'off')
  end
  
  def test_should_ignore_from
    assert @guard.matches?(@object, :to => 'on', :from => 'off')
  end
  
  def test_should_ignore_on
    assert @guard.matches?(@object, :to => 'on', :on => 'turn_on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on), @guard.known_states
  end
end

class GuardWithMultipleToRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:to => %w(on off))
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :to => 'on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :to => 'maybe')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on off), @guard.known_states
  end
end

class GuardWithFromRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:from => 'on')
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :from => 'on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :from => 'off')
  end
  
  def test_should_ignore_to
    assert @guard.matches?(@object, :from => 'on', :to => 'off')
  end
  
  def test_should_ignore_on
    assert @guard.matches?(@object, :from => 'on', :on => 'turn_on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on), @guard.known_states
  end
end

class GuardWithMultipleFromRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:from => %w(on off))
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :from => 'on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :from => 'maybe')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on off), @guard.known_states
  end
end

class GuardWithOnRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:on => 'turn_on')
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :on => 'turn_on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :on => 'turn_off')
  end
  
  def test_should_ignore_to
    assert @guard.matches?(@object, :on => 'turn_on', :to => 'off')
  end
  
  def test_should_ignore_from
    assert @guard.matches?(@object, :on => 'turn_on', :from => 'off')
  end
  
  def test_should_not_be_included_in_known_states
    assert_equal [], @guard.known_states
  end
end

class GuardWithMultipleOnRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:on => %w(turn_on turn_off))
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :on => 'turn_on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :on => 'turn_down')
  end
end

class GuardWithExceptToRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:except_to => 'off')
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :to => 'on')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :to => 'off')
  end
  
  def test_should_ignore_from
    assert @guard.matches?(@object, :except_to => 'off', :from => 'off')
  end
  
  def test_should_ignore_on
    assert @guard.matches?(@object, :except_to => 'off', :on => 'turn_on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(off), @guard.known_states
  end
end

class GuardWithMultipleExceptToRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:except_to => %w(on off))
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :to => 'maybe')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :to => 'on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on off), @guard.known_states
  end
end

class GuardWithExceptFromRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:except_from => 'off')
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :from => 'on')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :from => 'off')
  end
  
  def test_should_ignore_to
    assert @guard.matches?(@object, :from => 'on', :to => 'off')
  end
  
  def test_should_ignore_on
    assert @guard.matches?(@object, :from => 'on', :on => 'turn_on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(off), @guard.known_states
  end
end

class GuardWithMultipleExceptFromRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:except_from => %w(on off))
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :from => 'maybe')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :from => 'on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on off), @guard.known_states
  end
end

class GuardWithExceptOnRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:except_on => 'turn_off')
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :on => 'turn_on')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :on => 'turn_off')
  end
  
  def test_should_ignore_to
    assert @guard.matches?(@object, :on => 'turn_on', :to => 'off')
  end
  
  def test_should_ignore_from
    assert @guard.matches?(@object, :on => 'turn_on', :from => 'off')
  end
  
  def test_should_not_be_included_in_known_states
    assert_equal [], @guard.known_states
  end
end

class GuardWithMultipleExceptOnRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:except_on => %w(turn_on turn_off))
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :on => 'turn_down')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :on => 'turn_on')
  end
end

class GuardWithConflictingToRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:to => 'on', :except_to => 'on')
  end
  
  def test_should_ignore_except_requirement
    assert @guard.matches?(@object, :to => 'on')
  end
end

class GuardWithConflictingFromRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:from => 'on', :except_from => 'on')
  end
  
  def test_should_ignore_except_requirement
    assert @guard.matches?(@object, :from => 'on')
  end
end

class GuardWithConflictingOnRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:on => 'turn_on', :except_on => 'turn_on')
  end
  
  def test_should_ignore_except_requirement
    assert @guard.matches?(@object, :on => 'turn_on')
  end
end

class GuardWithDifferentRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = PluginAWeek::StateMachine::Guard.new(:from => 'off', :to => 'on', :on => 'turn_on')
  end
  
  def test_should_match_empty_query
    assert @guard.matches?(@object)
  end
  
  def test_should_match_if_all_requirements_match
    assert @guard.matches?(@object, :from => 'off', :to => 'on', :on => 'turn_on')
  end
  
  def test_should_not_match_if_from_not_included
    assert !@guard.matches?(@object, :from => 'on')
  end
  
  def test_should_not_match_if_to_not_included
    assert !@guard.matches?(@object, :to => 'off')
  end
  
  def test_should_not_match_if_on_not_included
    assert !@guard.matches?(@object, :on => 'turn_off')
  end
  
  def test_should_include_all_known_states
    assert_equal %w(off on), @guard.known_states.sort
  end
end

class GuardWithIfConditionalTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_match_if_true
    guard = PluginAWeek::StateMachine::Guard.new(:if => lambda {true})
    assert guard.matches?(@object)
  end
  
  def test_should_not_match_if_false
    guard = PluginAWeek::StateMachine::Guard.new(:if => lambda {false})
    assert !guard.matches?(@object)
  end
end

class GuardWithUnlessConditionalTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_match_if_false
    guard = PluginAWeek::StateMachine::Guard.new(:unless => lambda {false})
    assert guard.matches?(@object)
  end
  
  def test_should_not_match_if_true
    guard = PluginAWeek::StateMachine::Guard.new(:unless => lambda {true})
    assert !guard.matches?(@object)
  end
end

class GuardWithConflictingConditionalsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_match_if_true
    guard = PluginAWeek::StateMachine::Guard.new(:if => lambda {true}, :unless => lambda {true})
    assert guard.matches?(@object)
  end
  
  def test_should_not_match_if_false
    guard = PluginAWeek::StateMachine::Guard.new(:if => lambda {false}, :unless => lambda {false})
    assert !guard.matches?(@object)
  end
end
