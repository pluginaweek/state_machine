require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransitionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_have_an_object
    assert_equal @object, @transition.object
  end
  
  def test_should_have_a_machine
    assert_equal @machine, @transition.machine
  end
  
  def test_should_have_an_event
    assert_equal :ignite, @transition.event
  end
  
  def test_should_have_a_qualified_event
    assert_equal :ignite, @transition.qualified_event
  end
  
  def test_should_have_a_from_value
    assert_equal 'parked', @transition.from
  end
  
  def test_should_have_a_from_name
    assert_equal :parked, @transition.from_name
  end
  
  def test_should_have_a_qualified_from_name
    assert_equal :parked, @transition.qualified_from_name
  end
  
  def test_should_have_a_to_value
    assert_equal 'idling', @transition.to
  end
  
  def test_should_have_a_to_name
    assert_equal :idling, @transition.to_name
  end
  
  def test_should_have_a_qualified_to_name
    assert_equal :idling, @transition.qualified_to_name
  end
  
  def test_should_have_an_attribute
    assert_equal :state, @transition.attribute
  end
  
  def test_should_not_have_an_action
    assert_nil @transition.action
  end
  
  def test_should_generate_attributes
    expected = {:object => @object, :attribute => :state, :event => :ignite, :from => 'parked', :to => 'idling'}
    assert_equal expected, @transition.attributes
  end
  
  def test_should_have_empty_args
    assert_equal [], @transition.args
  end
  
  def test_should_not_have_a_result
    assert_nil @transition.result
  end
  
  def test_should_use_pretty_inspect
    assert_equal '#<StateMachine::Transition attribute=:state event=:ignite from="parked" from_name=:parked to="idling" to_name=:idling>', @transition.inspect
  end
end

class TransitionWithInvalidNodesTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_should_raise_exception_without_event
    assert_raise(IndexError) { StateMachine::Transition.new(@object, @machine, nil, :parked, :idling) }
  end
  
  def test_should_raise_exception_with_invalid_event
    assert_raise(IndexError) { StateMachine::Transition.new(@object, @machine, :invalid, :parked, :idling) }
  end
  
  def test_should_raise_exception_with_invalid_from_state
    assert_raise(IndexError) { StateMachine::Transition.new(@object, @machine, :ignite, :invalid, :idling) }
  end
  
  def test_should_raise_exception_with_invalid_to_state
    assert_raise(IndexError) { StateMachine::Transition.new(@object, @machine, :ignite, :parked, :invalid) }
  end
end

class TransitionWithDynamicToValueTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked
    @machine.state :idling, :value => lambda {1}
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_evaluate_to_value
    assert_equal 1, @transition.to
  end
end

class TransitionLoopbackTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked
    @machine.event :park
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :park, :parked, :parked)
  end
  
  def test_should_be_loopback
    assert @transition.loopback?
  end
end

class TransitionWithDifferentStatesTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_not_be_loopback
    assert !@transition.loopback?
  end
end

class TransitionWithNamespaceTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :namespace => 'alarm')
    @machine.state :off, :active
    @machine.event :activate
    
    @object = @klass.new
    @object.state = 'off'
    
    @transition = StateMachine::Transition.new(@object, @machine, :activate, :off, :active)
  end
  
  def test_should_have_an_event
    assert_equal :activate, @transition.event
  end
  
  def test_should_have_a_qualified_event
    assert_equal :activate_alarm, @transition.qualified_event
  end
  
  def test_should_have_a_from_name
    assert_equal :off, @transition.from_name
  end
  
  def test_should_have_a_qualified_from_name
    assert_equal :alarm_off, @transition.qualified_from_name
  end
  
  def test_should_have_a_to_name
    assert_equal :active, @transition.to_name
  end
  
  def test_should_have_a_qualified_to_name
    assert_equal :alarm_active, @transition.qualified_to_name
  end
end

class TransitionWithCustomMachineAttributeTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :state, :attribute => :state_id)
    @machine.state :off, :value => 1
    @machine.state :active, :value => 2
    @machine.event :activate
    
    @object = @klass.new
    @object.state_id = 1
    
    @transition = StateMachine::Transition.new(@object, @machine, :activate, :off, :active)
  end
  
  def test_should_persist
    @transition.persist
    assert_equal 2, @object.state_id
  end
  
  def test_should_rollback
    @object.state_id = 2
    @transition.rollback
    
    assert_equal 1, @object.state_id
  end
end

class TransitionWithoutReadingStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'idling'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling, false)
  end
  
  def test_should_not_read_from_value_from_object
    assert_equal 'parked', @transition.from
  end
  
  def test_should_have_to_value
    assert_equal 'idling', @transition.to
  end
end

class TransitionWithActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_have_an_action
    assert_equal :save, @transition.action
  end
  
  def test_should_not_have_a_result
    assert_nil @transition.result
  end
end

class TransitionAfterBeingPersistedTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @transition.persist
  end
  
  def test_should_update_state_value
    assert_equal 'idling', @object.state
  end
  
  def test_should_not_change_from_state
    assert_equal 'parked', @transition.from
  end
  
  def test_should_not_change_to_state
    assert_equal 'idling', @transition.to
  end
  
  def test_should_not_be_able_to_persist_twice
    @object.state = 'parked'
    @transition.persist
    assert_equal 'parked', @object.state
  end
  
  def test_should_be_able_to_persist_again_after_resetting
    @object.state = 'parked'
    @transition.reset
    @transition.persist
    assert_equal 'idling', @object.state
  end
  
  def test_should_revert_to_from_state_on_rollback
    @transition.rollback
    assert_equal 'parked', @object.state
  end
end

class TransitionAfterBeingRolledBackTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @object.state = 'idling'
    
    @transition.rollback
  end
  
  def test_should_update_state_value_to_from_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_change_from_state
    assert_equal 'parked', @transition.from
  end
  
  def test_should_not_change_to_state
    assert_equal 'idling', @transition.to
  end
  
  def test_should_still_be_able_to_persist
    @transition.persist
    assert_equal 'idling', @object.state
  end
end

class TransitionWithCallbacksTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved, :save_state
      
      def save
        @save_state = state
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_run_before_callbacks_on_before
    @machine.before_transition(lambda {|object| @run = true})
    result = @transition.before
    
    assert_equal true, result
    assert_equal true, @run
  end
  
  def test_should_run_before_callbacks_in_the_order_they_were_defined
    @callbacks = []
    @machine.before_transition(lambda {@callbacks << 1})
    @machine.before_transition(lambda {@callbacks << 2})
    @transition.before
    
    assert_equal [1, 2], @callbacks
  end
  
  def test_should_only_run_before_callbacks_that_match_transition_context
    @count = 0
    callback = lambda {@count += 1}
    
    @machine.before_transition :from => :parked, :to => :idling, :on => :park, :do => callback
    @machine.before_transition :from => :parked, :to => :parked, :on => :park, :do => callback
    @machine.before_transition :from => :parked, :to => :idling, :on => :ignite, :do => callback
    @machine.before_transition :from => :idling, :to => :idling, :on => :park, :do => callback
    @transition.before
    
    assert_equal 1, @count
  end
  
  def test_should_pass_transition_to_before_callbacks
    @machine.before_transition(lambda {|*args| @args = args})
    @transition.before
    
    assert_equal [@object, @transition], @args
  end
  
  def test_should_catch_halted_before_callbacks
    @machine.before_transition(lambda {throw :halt})
    
    result = nil
    assert_nothing_thrown { result = @transition.before }
    assert_equal false, result
  end
  
  def test_should_not_be_able_to_run_before_callbacks_twice
    @count = 0
    @machine.before_transition(lambda {@count += 1})
    @transition.before
    @transition.before
    assert_equal 1, @count
  end
  
  def test_should_be_able_to_run_before_callbacks_again_after_resetting
    @count = 0
    @machine.before_transition(lambda {@count += 1})
    @transition.before
    @transition.reset
    @transition.before
    assert_equal 2, @count
  end
  
  def test_should_run_after_callbacks_on_after
    @machine.after_transition(lambda {|object| @run = true})
    result = @transition.after(true)
    
    assert_equal true, result
    assert_equal true, @run
  end
  
  def test_should_set_result_on_after
    @transition.after
    assert_nil @transition.result
    
    @transition.after(1)
    assert_equal 1, @transition.result
  end
  
  def test_should_run_after_callbacks_in_the_order_they_were_defined
    @callbacks = []
    @machine.after_transition(lambda {@callbacks << 1})
    @machine.after_transition(lambda {@callbacks << 2})
    @transition.after(true)
    
    assert_equal [1, 2], @callbacks
  end
  
  def test_should_only_run_after_callbacks_that_match_transition_context
    @count = 0
    callback = lambda {@count += 1}
    
    @machine.after_transition :from => :parked, :to => :idling, :on => :park, :do => callback
    @machine.after_transition :from => :parked, :to => :parked, :on => :park, :do => callback
    @machine.after_transition :from => :parked, :to => :idling, :on => :ignite, :do => callback
    @machine.after_transition :from => :idling, :to => :idling, :on => :park, :do => callback
    @transition.after(true)
    
    assert_equal 1, @count
  end
  
  def test_should_not_run_after_callbacks_if_not_successful
    @machine.after_transition(lambda {|object| @run = true})
    @transition.after(nil, false)
    assert !@run
  end
  
  def test_should_pass_transition_to_after_callbacks
    @machine.after_transition(lambda {|*args| @args = args})
    
    @transition.after(true)
    assert_equal [@object, @transition], @args
    assert_equal true, @transition.result
    
    @transition.after(false)
    assert_equal [@object, @transition], @args
    assert_equal false, @transition.result
  end
  
  def test_should_catch_halted_after_callbacks
    @machine.after_transition(lambda {throw :halt})
    
    result = nil
    assert_nothing_thrown { result = @transition.after(true) }
    assert_equal true, result
  end
  
  def test_should_not_be_able_to_run_after_callbacks_twice
    @count = 0
    @machine.after_transition(lambda {@count += 1})
    @transition.after
    @transition.after
    assert_equal 1, @count
  end
  
  def test_should_be_able_to_run_after_callbacks_again_after_resetting
    @count = 0
    @machine.after_transition(lambda {@count += 1})
    @transition.after
    @transition.reset
    @transition.after
    assert_equal 2, @count
  end
end

class TransitionAfterBeingPerformedTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved, :save_state
      
      def save
        @save_state = state
        @saved = true
        1
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_have_empty_args
    assert_equal [], @transition.args
  end
  
  def test_should_have_a_result
    assert_equal 1, @transition.result
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_change_the_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_run_the_action
    assert @object.saved
  end
  
  def test_should_run_the_action_after_saving_the_state
    assert_equal 'idling', @object.save_state
  end
end

class TransitionWithPerformArgumentsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_have_arguments
    @transition.perform(1, 2)
    
    assert_equal [1, 2], @transition.args
    assert @object.saved
  end
  
  def test_should_not_include_run_action_in_arguments
    @transition.perform(1, 2, false)
    
    assert_equal [1, 2], @transition.args
    assert !@object.saved
  end
end

class TransitionWithoutRunningActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    @machine.after_transition(lambda {|object| @run_after = true})
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform(false)
  end
  
  def test_should_have_empty_args
    assert_equal [], @transition.args
  end
  
  def test_should_not_have_a_result
    assert_nil @transition.result
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_change_the_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_not_run_the_action
    assert !@object.saved
  end
  
  def test_should_run_after_callbacks
    assert @run_after
  end
end

class TransitionWithTransactionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self
        attr_accessor :running_transaction
      end
      
      attr_accessor :result
      
      def save
        @result = self.class.running_transaction
        true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    
    class << @machine
      def within_transaction(object)
        owner_class.running_transaction = object
        yield
        owner_class.running_transaction = false
      end
    end
  end
  
  def test_should_run_blocks_within_transaction_for_object
    @transition.within_transaction do
      @result = @klass.running_transaction
    end
    
    assert_equal @object, @result
  end
end
