require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransitionCollectionByDefaultTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ])
  end
  
  def test_should_not_skip_actions
    assert !@transitions.skip_actions
  end
  
  def test_should_not_skip_after
    assert !@transitions.skip_after
  end
  
  def test_should_use_transaction
    assert @transitions.use_transaction
  end
  
  def test_should_not_be_success
    assert !@transitions.success?
  end
  
  def test_should_not_have_any_results
    assert_equal e = {}, @transitions.results
  end
  
  def test_should_store_transitions
    assert_equal 1, @transitions.length
  end
end

class TransitionCollectionAfterBeingPersistedTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked)
    @state.state :idling
    @state.event :ignite
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
    @transitions.persist
  end
  
  def test_should_update_each_state_value
    assert_equal 'idling', @object.state
    assert_equal 'second_gear', @object.status
  end
  
  def test_should_not_change_success
    assert !@transitions.success?
  end
end

class TransitionCollectionAfterBeingRolledBackTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked)
    @state.state :idling
    @state.event :ignite
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
    
    @object.state = 'idling'
    @object.status = 'second_gear'
    
    @transitions.rollback
  end
  
  def test_should_update_each_state_value_to_from_state
    assert_equal 'parked', @object.state
    assert_equal 'first_gear', @object.status
  end
  
  def test_should_not_change_success
    assert !@transitions.success?
  end
end

class TransitionCollectionWithCallbacksTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @before_callbacks = []
    @after_callbacks = []
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked)
    @state.state :idling
    @state.event :ignite
    @state.before_transition {@before_callbacks << :state}
    @state.after_transition(:include_failures => true) {@after_callbacks << :state}
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear)
    @status.state :second_gear
    @status.event :shift_up
    @status.before_transition {@before_callbacks << :status}
    @status.after_transition(:include_failures => true) {@after_callbacks << :status}
    
    @object = @klass.new
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
  end
  
  def test_should_run_before_callbacks_in_order
    assert @transitions.before
    assert_equal [:state, :status], @before_callbacks
  end
  
  def test_should_halt_if_before_callback_halted_for_first_transition
    @state.before_transition {throw :halt}
    
    assert !@transitions.before
    assert_equal [:state], @before_callbacks
  end
  
  def test_should_halt_if_before_callback_halted_for_second_transition
    @status.before_transition {throw :halt}
    
    assert !@transitions.before
    assert_equal [:state, :status], @before_callbacks
  end
  
  def test_should_run_after_callbacks_in_order
    @transitions.after
    assert_equal [:state, :status], @after_callbacks
  end
  
  def test_should_not_halt_if_after_callback_halted_for_first_transition
    @state.after_transition(:include_failures => true) {throw :halt}
    
    @transitions.after
    assert_equal [:state, :status], @after_callbacks
  end
end

class TransitionCollectionAfterRunningEmptyActionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
    
    @object.state = 'idling'
    @object.status = 'second_gear'
    
    @transitions.run_actions
  end
  
  def test_should_change_success
    assert @transitions.success?
  end
  
  def test_should_not_rollback_state_values
    assert_equal 'idling', @object.state
    assert_equal 'second_gear', @object.status
  end
  
  def test_should_not_have_results
    assert_equal e = {}, @transitions.results
  end
  
  def test_should_store_results_in_transitions
    @transitions.after
    assert_nil @state_transition.result
    assert_nil @status_transition.result
  end
end

class TransitionCollectionAfterRunningSkippedActionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :actions
      
      def save_state
        (@actions ||= []) << :save_state
        :save_state
      end
      
      def save_status
        (@actions ||= []) << :save_status
        :save_status
      end
    end
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save_state)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :save_status)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ], :actions => false)
    @transitions.run_actions
  end
  
  def test_should_change_success
    assert @transitions.success?
  end
  
  def test_should_not_run_actions
    assert_nil @object.actions
  end
  
  def test_should_not_have_any_results
    assert_equal e = {}, @transitions.results
  end
  
  def test_should_store_results_in_transitions
    @transitions.after
    assert_nil @state_transition.result
    assert_nil @status_transition.result
  end
end

class TransitionCollectionAfterRunningDuplicateActionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :actions
      
      def save
        (@actions ||= []) << :save
        :save
      end
    end
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :save)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
    @transitions.run_actions
  end
  
  def test_should_change_success
    assert @transitions.success?
  end
  
  def test_should_run_action_once
    assert_equal [:save], @object.actions
  end
  
  def test_should_have_results
    assert_equal e = {:save => :save}, @transitions.results
  end
  
  def test_should_store_results_in_transitions
    @transitions.after
    assert_equal :save, @state_transition.result
    assert_equal :save, @status_transition.result
  end
end

class TransitionCollectionAfterRunningDifferentActionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :actions
      
      def save_state
        (@actions ||= []) << :save_state
        :save_state
      end
      
      def save_status
        (@actions ||= []) << :save_status
        :save_status
      end
    end
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save_state)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :save_status)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
  end
  
  def test_should_change_success
    @transitions.run_actions
    assert @transitions.success?
  end
  
  def test_should_run_actions_in_order
    @transitions.run_actions
    assert_equal [:save_state, :save_status], @object.actions
  end
  
  def test_should_have_results
    @transitions.run_actions
    assert_equal e = {:save_state => :save_state, :save_status => :save_status}, @transitions.results
  end
  
  def test_should_store_results_in_transitions
    @transitions.run_actions
    @transitions.after
    assert_equal :save_state, @state_transition.result
    assert_equal :save_status, @status_transition.result
  end
  
  def test_should_not_halt_if_action_fails_for_first_transition
    @klass.class_eval do
      def save_state
        (@actions ||= []) << :save_state
        false
      end
    end
    
    @transitions.run_actions
    assert !@transitions.success?
    assert_equal [:save_state, :save_status], @object.actions
  end
  
  def test_should_halt_if_action_fails_for_second_transition
    @klass.class_eval do
      def save_status
        (@actions ||= []) << :save_status
        false
      end
    end
    
    @transitions.run_actions
    assert_equal false, @transitions.success?
    assert_equal [:save_state, :save_status], @object.actions
  end
  
  def test_should_rollback_if_action_errors_for_first_transition
    @klass.class_eval do
      def save_state
        raise ArgumentError
      end
    end
    
    begin; @transitions.run_actions; rescue; end
    assert_equal 'parked', @object.state
    assert_equal 'first_gear', @object.status
  end
  
  def test_should_rollback_if_action_errors_for_second_transition
    @klass.class_eval do
      def save_status
        raise ArgumentError
      end
    end
    
    begin; @transitions.run_actions; rescue; end
    assert_equal 'parked', @object.state
    assert_equal 'first_gear', @object.status
  end
  
  def test_should_not_run_after_callbacks_if_action_fails_for_first_transition
    @klass.class_eval do
      def save_state
        false
      end
    end
    
    ran_state_callback = false
    ran_status_callback = false
    @state.after_transition { ran_state_callback = true }
    @status.after_transition { ran_status_callback = true }
    
    @transitions.run_actions
    @transitions.after
    assert !ran_state_callback
    assert !ran_status_callback
  end
  
  def test_should_not_run_after_callbacks_if_action_fails_for_second_transition
    @klass.class_eval do
      def save_status
        false
      end
    end
    
    ran_state_callback = false
    ran_status_callback = false
    @state.after_transition { ran_state_callback = true }
    @status.after_transition { ran_status_callback = true }
    
    @transitions.run_actions
    @transitions.after
    assert !ran_state_callback
    assert !ran_status_callback
  end
  
  def test_should_run_after_failure_callbacks_if_action_fails_for_first_transition
    @klass.class_eval do
      def save_state
        false
      end
    end
    
    ran_state_callback = false
    ran_status_callback = false
    @state.after_transition(:include_failures => true) { ran_state_callback = true }
    @status.after_transition(:include_failures => true) { ran_status_callback = true }
    
    @transitions.run_actions
    @transitions.after
    assert ran_state_callback
    assert ran_status_callback
  end
  
  def test_should_run_after_failure_callbacks_if_action_fails_for_second_transition
    @klass.class_eval do
      def save_status
        false
      end
    end
    
    ran_state_callback = false
    ran_status_callback = false
    @state.after_transition(:include_failures => true) { ran_state_callback = true }
    @status.after_transition(:include_failures => true) { ran_status_callback = true }
    
    @transitions.run_actions
    @transitions.after
    assert ran_state_callback
    assert ran_status_callback
  end
end

class TransitionsAfterRunningWithMixedActionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
        true
      end
    end
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
    @result = @transitions.run_actions
  end
  
  def test_should_succeed
    assert @result
  end
  
  def test_should_be_success
    assert @transitions.success?
  end
  
  def test_should_have_results
    assert_equal e = {:save => true}, @transitions.results
  end
  
  def test_should_store_results_in_transitions
    @transitions.after
    assert_equal true, @state_transition.result
    assert_nil @status_transition.result
  end
end

class TransitionCollectionAfteRunningWithNonBooleanResultTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
        Object.new
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ])
    @result = @transitions.run_actions
  end
  
  def test_should_succeed
    assert_equal true, @result
  end
  
  def test_should_be_successful
    assert @transitions.success?
  end
end

class TransitionsAfterRunningWithBlockTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @state = StateMachine::Machine.new(@klass, :state, :initial => :parked)
    @state.state  :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    @transitions = StateMachine::TransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
  end
  
  def test_should_be_successful_if_result_is_not_false
    @transitions.run_actions { true }
    assert @transitions.success?
  end
  
  def test_should_not_be_successful_if_result_is_false
    @transitions.run_actions { false }
    assert !@transitions.success?
  end
  
  def test_should_not_be_successful_if_result_is_nil
    @transitions.run_actions { nil }
    assert !@transitions.success?
  end
  
  def test_should_have_results
    @transitions.run_actions { 1 }
    assert_equal e = {nil => 1}, @transitions.results
  end
  
  def test_should_use_result_as_transition_result
    @transitions.run_actions { 1 }
    @transitions.after
    assert_equal 1, @state_transition.result
    assert_equal 1, @status_transition.result
  end
end

class TransitionCollectionPerformTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :persisted
      
      def initialize
        @persisted = []
        @state = 'parked'
        @status = 'first_gear'
        super
      end
      
      def state=(value)
        @persisted << value
        @state = value
      end
      
      def status=(value)
        @persisted << value
        @status = value
      end
    end
    
    @state = StateMachine::Machine.new(@klass)
    @state.state :parked, :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status)
    @status.state :first_gear, :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
    @result = @transitions.perform
  end
  
  def test_should_succeed
    assert_equal true, @result
  end
  
  def test_should_be_success
    assert @transitions.success?
  end
  
  def test_should_persist_each_state
    assert_equal 'idling', @object.state
    assert_equal 'second_gear', @object.status
  end
  
  def test_should_persist_in_order
    assert_equal ['idling', 'second_gear'], @object.persisted
  end
end

class TransitionCollectionPerformWithoutTransactionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_accessor :ran_transaction
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @machine.state :idling
    @machine.event :ignite
    
    class << @machine
      def within_transaction(object)
        object.ran_transaction = true
      end
    end
    
    @object = @klass.new
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ], :transaction => false)
    @transitions.perform
  end
  
  def test_should_not_run_within_transaction
    assert !@object.ran_transaction
  end
end

class TransitionCollectionPerformWithTransactionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_accessor :running_transaction, :cancelled_transaction, :result
      
      def save
        self.result = running_transaction
        true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    
    class << @machine
      def within_transaction(object)
        object.running_transaction = true
        object.cancelled_transaction = yield == false
        object.running_transaction = false
      end
    end
    
    @object = @klass.new
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ], :transaction => true)
  end
  
  def test_should_run_before_callbacks_within_transaction
    @machine.before_transition {|object| @in_transaction = object.running_transaction}
    @transitions.perform
    
    assert @in_transaction
  end
  
  def test_should_run_action_within_transaction
    @transitions.perform
    
    assert @object.result
  end
  
  def test_should_run_after_callbacks_within_transaction
    @machine.after_transition {|object| @in_transaction = object.running_transaction}
    @transitions.perform
    
    assert @in_transaction
  end
  
  def test_should_cancel_the_transaction_on_before_halt
    @machine.before_transition {throw :halt}
    
    @transitions.perform
    assert @object.cancelled_transaction
  end
  
  def test_should_cancel_the_transaction_on_action_failure
    @klass.class_eval do
      def save
        false
      end
    end
    
    @transitions.perform
    assert @object.cancelled_transaction
  end
  
  def test_should_not_cancel_the_transaction_on_after_halt
    @machine.after_transition {throw :halt}
    
    @transitions.perform
    assert !@object.cancelled_transaction
  end
end

class TransitionCollectionPerformWithoutRunningActionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    @machine.before_transition {@ran_before = true}
    @machine.after_transition {@ran_after = true}
    
    @object = @klass.new
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ], :actions => false)
    @transitions.perform
  end
  
  def test_should_succeed
    assert_equal true, @transitions.perform
  end
  
  def test_should_be_success
    assert @transitions.success?
  end
  
  def test_should_not_call_action
    assert !@object.saved
  end
  
  def test_should_persist_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_still_run_before_callbacks
    assert @ran_before
  end
  
  def test_should_still_run_after_callbacks
    assert @ran_after
  end
end

class TransitionCollectionPerformWithActionFailedTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
        false
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    
    @machine.before_transition {@before_count += 1}
    @machine.after_transition {@after_count += 1}
    @machine.after_transition(:include_failures => true) {@after_count += 1}
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ])
    @result = @transitions.perform
  end
  
  def test_should_not_be_successful
    assert_equal false, @result
  end
  
  def test_should_not_change_current_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_run_before_callbacks
    assert_equal 1, @before_count
  end
  
  def test_should_only_run_after_callbacks_that_include_failures
    assert_equal 1, @after_count
  end
end

class TransitionCollectionPerformWithActionErrorTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
        raise ArgumentError
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ])
    
    @raised = true
    begin
      @transitions.perform
      @raised = false
    rescue ArgumentError
    end
  end
  
  def test_should_not_catch_exception
    assert @raised
  end
  
  def test_should_not_change_current_state
    assert_equal 'parked', @object.state
  end
end

class TransitionCollectionPerformWithCallbacksTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ])
  end
  
  def test_should_run_before_callbacks_before_changing_the_state
    @machine.before_transition {|object| @state = object.state}
    @transitions.perform
    
    assert_equal 'parked', @state
  end
  
  def test_should_persist_state_before_running_action
    @klass.class_eval do
      attr_reader :saved_on_persist
      
      def state=(value)
        @state = value
        @saved_on_persist = saved
      end
    end
    
    @transitions.perform
    assert !@object.saved_on_persist
  end
  
  def test_should_run_after_callbacks_after_running_the_action
    @machine.after_transition {|object| @state = object.state}
    @transitions.perform
    
    assert_equal 'idling', @state
  end
end

class TransitionCollectionPerformHaltedDuringBeforeCallbacksTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    
    @machine.before_transition {@before_count += 1; throw :halt}
    @machine.before_transition {@before_count += 1}
    @machine.after_transition {@after_count += 1}
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ])
    @result = @transitions.perform
  end
  
  def test_should_not_be_successful
    assert_equal false, @result
  end
  
  def test_should_not_change_current_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_run_action
    assert !@object.saved
  end
  
  def test_should_not_run_further_before_callbacks
    assert_equal 1, @before_count
  end
  
  def test_should_not_run_after_callbacks
    assert_equal 0, @after_count
  end
end

class TransitionCollectionPerformHaltedAfterCallbackTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    
    @machine.before_transition {@before_count += 1}
    @machine.after_transition {@after_count += 1; throw :halt}
    @machine.after_transition {@after_count += 1}
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ])
    @result = @transitions.perform
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_change_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_run_before_callbacks
    assert_equal 1, @before_count
  end
  
  def test_should_not_run_further_after_callbacks
    assert_equal 1, @after_count
  end
end

class TransitionCollectionOnPerformWithoutAfterTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @machine.state :idling
    @machine.event :ignite
    @machine.after_transition {@ran_after = true}
    
    @object = @klass.new
    
    @transitions = StateMachine::TransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ], :after => false)
    @result = @transitions.perform
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_not_run_after_callbacks
    assert !@ran_after
  end
end

class AttributeTransitionCollectionByDefaultTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state_event = 'ignite'
    
    @transitions = StateMachine::AttributeTransitionCollection.new([
      StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ])
  end
  
  def test_should_not_skip_actions
    assert !@transitions.skip_actions
  end
  
  def test_should_not_skip_after
    assert !@transitions.skip_after
  end
  
  def test_should_use_transaction
    assert @transitions.use_transaction
  end
  
  def test_should_not_be_success
    assert !@transitions.success?
  end
end

class AttributeTransitionCollectionOnBeforeTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :save)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::AttributeTransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
  end
  
  def test_should_clear_each_event
    @object.state_event = 'ignite'
    @object.status_event = 'shift_up'
    @transitions.before
    
    assert_nil @object.state_event
    assert_nil @object.status_event
  end
  
  def test_should_clear_each_event_transition
    @object.send(:state_event_transition=, @state_transition)
    @object.send(:status_event_transition=, @state_transition)
    @transitions.before
    
    assert_nil @object.send(:state_event_transition)
    assert_nil @object.send(:status_event_transition)
  end
  
  def test_should_not_have_event_during_before_callbacks
    state_event = nil
    @state.before_transition {|object, transition| state_event = object.state_event }
    @transitions.before
    
    assert_nil state_event
  end
  
  def test_should_not_have_event_transition_during_before_callbacks
    state_event_transition = @state_transition
    @state.before_transition {|object, transition| state_event_transition = object.send(:state_event_transition) }
    @transitions.before
    
    assert_nil state_event_transition
  end
end

class AttributeTransitionCollectionOnAfterTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :save)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::AttributeTransitionCollection.new([
      StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
  end
  
  def test_should_not_reset_event
    @transitions.after
    assert_nil @object.state_event
    assert_nil @object.status_event
  end
  
  def test_should_not_set_event_transitions_if_success
    @transitions.run_actions { true }
    @transitions.after
    assert_nil @object.send(:state_event_transition)
    assert_nil @object.send(:status_event_transition)
  end
  
  def test_should_not_set_event_transitions_if_failed
    @transitions.run_actions { false }
    @transitions.after
    assert_nil @object.send(:state_event_transition)
    assert_nil @object.send(:status_event_transition)
  end
end

class AttributeTransitionCollectionWithoutAfterTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :save)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::AttributeTransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ], :after => false)
  end
  
  def test_should_not_reset_event
    @transitions.after
    assert_nil @object.state_event
    assert_nil @object.status_event
  end
  
  def test_should_set_event_transitions_if_success
    @transitions.run_actions { true }
    @transitions.after
    assert_equal @state_transition, @object.send(:state_event_transition)
    assert_equal @status_transition, @object.send(:status_event_transition)
  end
  
  def test_should_not_set_event_transitions_if_failed
    @transitions.run_actions { false }
    @transitions.after
    assert_nil @object.send(:state_event_transition)
    assert_nil @object.send(:status_event_transition)
  end
end

class AttributeTransitionCollectionAfterRollbackTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :save)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    
    @transitions = StateMachine::AttributeTransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
    @transitions.rollback
  end
  
  def test_should_set_each_event
    assert_equal :ignite, @object.state_event
    assert_equal :shift_up, @object.status_event
  end
  
  def test_should_not_set_each_event_transition
    assert_nil @object.send(:state_event_transition)
    assert_nil @object.send(:status_event_transition)
  end
end

class AttributeTransitionCollectionPerformTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    
    @state = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @state.state :idling
    @state.event :ignite
    
    @status = StateMachine::Machine.new(@klass, :status, :initial => :first_gear, :action => :save)
    @status.state :second_gear
    @status.event :shift_up
    
    @object = @klass.new
    @object.state_event = 'ignite'
    @object.status_event = 'shift_up'
    
    @transitions = StateMachine::AttributeTransitionCollection.new([
      @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling),
      @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
    ])
    
    @state_event = nil
    @status_event = nil
    
    @result = @transitions.perform do
      @state_event = @object.state_event
      @status_event = @object.status_event
      true
    end
  end
  
  def test_should_succeed
    assert_equal true, @result
  end
  
  def test_should_not_have_event_while_running_action
    assert_nil @state_event
    assert_nil @status_event
  end
  
  def test_should_transition_each_state
    assert_equal 'idling', @object.state
    assert_equal 'second_gear', @object.status
  end
  
  def test_should_reset_each_event_attribute
    assert_nil @object.state_event
    assert_nil @object.status_event
  end
  
  def test_should_not_have_event_transition
    assert_nil @object.send(:state_event_transition)
    assert_nil @object.send(:status_event_transition)
  end
end

class AttributeTransitionCollectionMarshallingTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    self.class.const_set('Example', @klass)
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked, :action => :save)
    @machine.state :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state_event = 'ignite'
  end
  
  def test_should_marshal_during_before_callbacks
    @machine.before_transition {|object, transition| Marshal.dump(object)}
    assert_nothing_raised do
      transitions(:after => false).perform { true }
      transitions.perform { true }
    end
  end
  
  def test_should_marshal_during_action
    assert_nothing_raised do
      transitions(:after => false).perform do
         Marshal.dump(@object)
         true
      end
      
      transitions.perform do
         Marshal.dump(@object)
         true
      end
    end
  end
  
  def test_should_marshal_during_after_callbacks
    @machine.after_transition {|object, transition| Marshal.dump(object)}
    assert_nothing_raised do
      transitions(:after => false).perform { true }
      transitions.perform { true }
    end
  end
  
  def teardown
    self.class.send(:remove_const, 'Example')
  end
  
  private
    def transitions(options = {})
      StateMachine::AttributeTransitionCollection.new([
        StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
      ], options)
    end
end
