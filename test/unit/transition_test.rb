require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransitionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    
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
  
  def test_should_have_a_from_value
    assert_equal 'parked', @transition.from
  end
  
  def test_should_have_a_from_name
    assert_equal :parked, @transition.from_name
  end
  
  def test_should_have_a_to_value
    assert_equal 'idling', @transition.to
  end
  
  def test_should_have_a_to_name
    assert_equal :idling, @transition.to_name
  end
  
  def test_should_have_an_attribute
    assert_equal :state, @transition.attribute
  end
  
  def test_should_generate_attributes
    expected = {:object => @object, :attribute => :state, :event => :ignite, :from => 'parked', :to => 'idling'}
    assert_equal expected, @transition.attributes
  end
  
  def test_should_use_pretty_inspect
    assert_equal '#<StateMachine::Transition attribute=:state event=:ignite from="parked" from_name=:parked to="idling" to_name=:idling>', @transition.inspect
  end
end

class TransitionWithDynamicToValueTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked
    @machine.state :idling, :value => lambda {1}
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_evaluate_to_value
    assert_equal 1, @transition.to
  end
end

class TransitionAfterBeingPerformedTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved, :save_state
      
      def save
        @save_state = state
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_the_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_run_the_action
    assert @object.saved
  end
  
  def test_should_run_the_action_after_saving_the_state
    assert_equal 'idling', @object.save_state
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
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform(false)
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_the_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_not_run_the_action
    assert !@object.saved
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
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_run_before_callbacks_before_changing_the_state
    @machine.before_transition(lambda {|object| @state = object.state})
    @transition.perform
    
    assert_equal 'parked', @state
  end
  
  def test_should_run_after_callbacks_after_running_the_action
    @machine.after_transition(lambda {|object| @state = object.state})
    @transition.perform
    
    assert_equal 'idling', @state
  end
  
  def test_should_run_before_callbacks_in_the_order_they_were_defined
    @callbacks = []
    @machine.before_transition(lambda {@callbacks << 1})
    @machine.before_transition(lambda {@callbacks << 2})
    @transition.perform
    
    assert_equal [1, 2], @callbacks
  end
  
  def test_should_run_after_callbacks_in_the_order_they_were_defined
    @callbacks = []
    @machine.after_transition(lambda {@callbacks << 1})
    @machine.after_transition(lambda {@callbacks << 2})
    @transition.perform
    
    assert_equal [1, 2], @callbacks
  end
  
  def test_should_only_run_before_callbacks_that_match_transition_context
    @count = 0
    callback = lambda {@count += 1}
    
    @machine.before_transition :from => :parked, :to => :idling, :on => :park, :do => callback
    @machine.before_transition :from => :parked, :to => :parked, :on => :park, :do => callback
    @machine.before_transition :from => :parked, :to => :idling, :on => :ignite, :do => callback
    @machine.before_transition :from => :idling, :to => :idling, :on => :park, :do => callback
    @transition.perform
    
    assert_equal 1, @count
  end
  
  def test_should_only_run_after_callbacks_that_match_transition_context
    @count = 0
    callback = lambda {@count += 1}
    
    @machine.after_transition :from => :parked, :to => :idling, :on => :park, :do => callback
    @machine.after_transition :from => :parked, :to => :parked, :on => :park, :do => callback
    @machine.after_transition :from => :parked, :to => :idling, :on => :ignite, :do => callback
    @machine.after_transition :from => :idling, :to => :idling, :on => :park, :do => callback
    @transition.perform
    
    assert_equal 1, @count
  end
  
  def test_should_pass_transition_to_before_callbacks
    @machine.before_transition(lambda {|*args| @args = args})
    @transition.perform
    
    assert_equal [@object, @transition], @args
  end
  
  def test_should_pass_transition_and_action_result_to_after_callbacks
    @machine.after_transition(lambda {|*args| @args = args})
    @transition.perform
    
    assert_equal [@object, @transition, true], @args
  end
end

class TransitionHaltedDuringBeforeCallbacksTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self; attr_accessor :cancelled_transaction; end
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    class << @machine
      def within_transaction(object)
        owner_class.cancelled_transaction = yield == false
      end
    end
    
    @machine.before_transition lambda {@before_count += 1; throw :halt}
    @machine.before_transition lambda {@before_count += 1}
    @machine.after_transition lambda {@after_count += 1}
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_not_be_successful
    assert !@result
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
  
  def test_should_cancel_the_transaction
    assert @klass.cancelled_transaction
  end
end

class TransitionHaltedDuringActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self; attr_accessor :cancelled_transaction; end
      attr_reader :saved
      
      def save
        throw :halt
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    class << @machine
      def within_transaction(object)
        owner_class.cancelled_transaction = yield == false
      end
    end
    
    @machine.before_transition lambda {@before_count += 1}
    @machine.after_transition lambda {@after_count += 1}
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_not_be_successful
    assert !@result
  end
  
  def test_should_change_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_run_before_callbacks
    assert_equal 1, @before_count
  end
  
  def test_should_not_run_after_callbacks
    assert_equal 0, @after_count
  end
  
  def test_should_cancel_the_transaction
    assert @klass.cancelled_transaction
  end
end

class TransitionHaltedAfterCallbackTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self; attr_accessor :cancelled_transaction; end
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    class << @machine
      def within_transaction(object)
        owner_class.cancelled_transaction = yield == false
      end
    end
    
    @machine.before_transition lambda {@before_count += 1}
    @machine.after_transition lambda {@after_count += 1; throw :halt}
    @machine.after_transition lambda {@after_count += 1}
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_be_successful
    assert @result
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
  
  def test_should_not_cancel_the_transaction
    assert !@klass.cancelled_transaction
  end
end

class TransitionWithFailedActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self; attr_accessor :cancelled_transaction; end
      attr_reader :saved
      
      def save
        false
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    class << @machine
      def within_transaction(object)
        owner_class.cancelled_transaction = yield == false
      end
    end
    
    @machine.before_transition lambda {@before_count += 1}
    @machine.after_transition lambda {@after_count += 1}
    
    @object = @klass.new
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_not_be_successful
    assert !@result
  end
  
  def test_should_change_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_run_before_callbacks
    assert_equal 1, @before_count
  end
  
  def test_should_run_after_callbacks
    assert_equal 1, @after_count
  end
  
  def test_should_cancel_the_transaction
    assert @klass.cancelled_transaction
  end
end
