require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class CallbackTest < Test::Unit::TestCase
  def test_should_raise_exception_if_do_option_not_specified
    exception = assert_raise(ArgumentError) { StateMachine::Callback.new }
    assert_match ':do callback must be specified', exception.message
  end
  
  def test_should_not_raise_exception_if_do_option_specified
    assert_nothing_raised { StateMachine::Callback.new(:do => :run) }
  end
  
  def test_should_not_raise_exception_if_implicit_option_specified
    assert_nothing_raised { StateMachine::Callback.new(:do => :run, :invalid => true) }
  end
  
  def test_should_not_bind_to_objects
    assert !StateMachine::Callback.bind_to_object
  end
end

class CallbackByDefaultTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @method = lambda {|*args| args.unshift(self)}
    @callback = StateMachine::Callback.new(:do => @method)
  end
  
  def test_should_not_have_a_terminator
    assert_nil @callback.terminator
  end
  
  def test_should_have_a_guard_with_all_matcher_requirements
    assert_equal StateMachine::AllMatcher.instance, @callback.guard.event_requirement
    assert_equal StateMachine::AllMatcher.instance, @callback.guard.state_requirements.first[:from]
    assert_equal StateMachine::AllMatcher.instance, @callback.guard.state_requirements.first[:to]
  end
  
  def test_should_not_bind_to_the_object
    assert_equal [self, @object], @callback.call(@object)
  end
  
  def test_should_not_have_any_known_states
    assert_equal [], @callback.known_states
  end
end

class CallbackWithOnlyMethodTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @callback = StateMachine::Callback.new(lambda {true})
  end
  
  def test_should_call_with_empty_context
    assert @callback.call(@object)
  end
end

class CallbackWithExplicitRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @callback = StateMachine::Callback.new(:from => :parked, :to => :idling, :on => :ignite, :do => lambda {true})
  end
  
  def test_should_call_with_empty_context
    assert @callback.call(@object, {})
  end
  
  def test_should_not_call_if_from_not_included
    assert !@callback.call(@object, :from => :idling)
  end
  
  def test_should_not_call_if_to_not_included
    assert !@callback.call(@object, :to => :parked)
  end
  
  def test_should_not_call_if_on_not_included
    assert !@callback.call(@object, :on => :park)
  end
  
  def test_should_call_if_all_requirements_met
    assert @callback.call(@object, :from => :parked, :to => :idling, :on => :ignite)
  end
  
  def test_should_include_in_known_states
    assert_equal [:parked, :idling], @callback.known_states
  end
end

class CallbackWithImplicitRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @callback = StateMachine::Callback.new(:parked => :idling, :on => :ignite, :do => lambda {true})
  end
  
  def test_should_call_with_empty_context
    assert @callback.call(@object, {})
  end
  
  def test_should_not_call_if_from_not_included
    assert !@callback.call(@object, :from => :idling)
  end
  
  def test_should_not_call_if_to_not_included
    assert !@callback.call(@object, :to => :parked)
  end
  
  def test_should_not_call_if_on_not_included
    assert !@callback.call(@object, :on => :park)
  end
  
  def test_should_call_if_all_requirements_met
    assert @callback.call(@object, :from => :parked, :to => :idling, :on => :ignite)
  end
  
  def test_should_include_in_known_states
    assert_equal [:parked, :idling], @callback.known_states
  end
end

class CallbackWithIfConditionTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_call_if_true
    callback = StateMachine::Callback.new(:if => lambda {true}, :do => lambda {true})
    assert callback.call(@object)
  end
  
  def test_should_not_call_if_false
    callback = StateMachine::Callback.new(:if => lambda {false}, :do => lambda {true})
    assert !callback.call(@object)
  end
end

class CallbackWithUnlessConditionTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_call_if_false
    callback = StateMachine::Callback.new(:unless => lambda {false}, :do => lambda {true})
    assert callback.call(@object)
  end
  
  def test_should_not_call_if_true
    callback = StateMachine::Callback.new(:unless => lambda {true}, :do => lambda {true})
    assert !callback.call(@object)
  end
end

class CallbackWithoutTerminatorTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_not_halt_if_result_is_false
    callback = StateMachine::Callback.new(:do => lambda {false}, :terminator => nil)
    assert_nothing_thrown { callback.call(@object) }
  end
end

class CallbackWithTerminatorTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_not_halt_if_terminator_does_not_match
    callback = StateMachine::Callback.new(:do => lambda {false}, :terminator => lambda {|result| false})
    assert_nothing_thrown { callback.call(@object) }
  end
  
  def test_should_halt_if_terminator_matches
    callback = StateMachine::Callback.new(:do => lambda {false}, :terminator => lambda {|result| true})
    assert_throws(:halt) { callback.call(@object) }
  end
end

class CallbackWithoutArgumentsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @callback = StateMachine::Callback.new(:do => lambda {|object| object})
  end
  
  def test_should_call_method_with_object_as_argument
    assert_equal @object, @callback.call(@object, {}, 1, 2, 3)
  end
end

class CallbackWithArgumentsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @callback = StateMachine::Callback.new(:do => lambda {|*args| args})
  end
  
  def test_should_call_method_with_all_arguments
    assert_equal [@object, 1, 2, 3], @callback.call(@object, {}, 1, 2, 3)
  end
end

class CallbackWithUnboundObjectTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @callback = StateMachine::Callback.new(:do => lambda {|*args| args.unshift(self)})
  end
  
  def test_should_call_method_outside_the_context_of_the_object
    assert_equal [self, @object, 1, 2, 3], @callback.call(@object, {}, 1, 2, 3)
  end
end

class CallbackWithBoundObjectTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @callback = StateMachine::Callback.new(:do => lambda {|*args| args.unshift(self)}, :bind_to_object => true)
  end
  
  def test_should_call_method_within_the_context_of_the_object
    assert_equal [@object, 1, 2, 3], @callback.call(@object, {}, 1, 2, 3)
  end
  
  def test_should_ignore_option_for_symbolic_callbacks
    class << @object
      def after_ignite(*args)
        args
      end
    end
    
    @callback = StateMachine::Callback.new(:do => :after_ignite, :bind_to_object => true)
    assert_equal [], @callback.call(@object)
  end
  
  def test_should_ignore_option_for_string_callbacks
    @callback = StateMachine::Callback.new(:do => '[1, 2, 3]', :bind_to_object => true)
    assert_equal [1, 2, 3], @callback.call(@object)
  end
end
