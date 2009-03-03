require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StateCollectionByDefaultTest < Test::Unit::TestCase
  def setup
    @states = StateMachine::StateCollection.new
  end
  
  def test_should_not_have_any_nodes
    assert_equal 0, @states.length
  end
  
  def test_should_be_empty_by_priority
    assert_equal [], @states.by_priority
  end
end

class StateCollectionWithInitialStateTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    
    @states = StateMachine::StateCollection.new
    @states << @parked = StateMachine::State.new(@machine, :parked)
    @states << @idling = StateMachine::State.new(@machine, :idling)
    
    @parked.initial = true
  end
  
  def test_should_order_state_before_transition_states
    @machine.event :ignite do
      transition :to => :idling
    end
    assert_equal [@parked, @idling], @states.by_priority
  end
  
  def test_should_order_state_before_states_with_behaviors
    @idling.context do
      def speed
        0
      end
    end
    assert_equal [@parked, @idling], @states.by_priority
  end
  
  def test_should_order_state_before_other_states
    assert_equal [@parked, @idling], @states.by_priority
  end
  
  def test_should_order_state_before_callback_states
    @machine.before_transition :from => :idling, :do => lambda {}
    assert_equal [@parked, @idling], @states.by_priority
  end
end

class StateCollectionWithStateBehaviorsTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    
    @states = StateMachine::StateCollection.new
    @states << @parked = StateMachine::State.new(@machine, :parked)
    @states << @idling = StateMachine::State.new(@machine, :idling)
    
    @idling.context do
      def speed
        0
      end
    end
  end
  
  def test_should_order_states_after_initial_state
    @parked.initial = true
    assert_equal [@parked, @idling], @states.by_priority
  end
  
  def test_should_order_states_after_transition_states
    @machine.event :ignite do
      transition :from => :parked
    end
    assert_equal [@parked, @idling], @states.by_priority
  end
  
  def test_should_order_states_before_other_states
    assert_equal [@idling, @parked], @states.by_priority
  end
  
  def test_should_order_state_before_callback_states
    @machine.before_transition :from => :parked, :do => lambda {}
    assert_equal [@idling, @parked], @states.by_priority
  end
end

class StateCollectionWithEventTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    
    @states = StateMachine::StateCollection.new
    @states << @parked = StateMachine::State.new(@machine, :parked)
    @states << @idling = StateMachine::State.new(@machine, :idling)
    
    @machine.event :ignite do
      transition :to => :idling
    end
  end
  
  def test_should_order_states_after_initial_state
    @parked.initial = true
    assert_equal [@parked, @idling], @states.by_priority
  end
  
  def test_should_order_states_before_states_with_behaviors
    @parked.context do
      def speed
        0
      end
    end
    assert_equal [@idling, @parked], @states.by_priority
  end
  
  def test_should_order_states_before_other_states
    assert_equal [@idling, @parked], @states.by_priority
  end
  
  def test_should_order_state_before_callback_states
    @machine.before_transition :from => :parked, :do => lambda {}
    assert_equal [@idling, @parked], @states.by_priority
  end
end

class StateCollectionWithTransitionCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    
    @states = StateMachine::StateCollection.new
    @states << @parked = StateMachine::State.new(@machine, :parked)
    @states << @idling = StateMachine::State.new(@machine, :idling)
    
    @machine.before_transition :to => :idling, :do => lambda {}
  end
  
  def test_should_order_states_after_initial_state
    @parked.initial = true
    assert_equal [@parked, @idling], @states.by_priority
  end
  
  def test_should_order_states_after_transition_states
    @machine.event :ignite do
      transition :from => :parked
    end
    assert_equal [@parked, @idling], @states.by_priority
  end
  
  def test_should_order_states_after_states_with_behaviors
    @parked.context do
      def speed
        0
      end
    end
    assert_equal [@parked, @idling], @states.by_priority
  end
  
  def test_should_order_states_after_other_states
    assert_equal [@parked, @idling], @states.by_priority
  end
end
