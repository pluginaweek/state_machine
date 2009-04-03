require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class Validateable
  class << self
    def validate(*args, &block)
      args << block if block_given?
      args
    end
  end
end

class ConditionProxyTest < Test::Unit::TestCase
  def test_should_call_class_with_same_arguments
    options = {}
    condition_proxy = StateMachine::ConditionProxy.new(Validateable, lambda {})
    validation = condition_proxy.validate(:name, options)
    
    assert_equal [:name, options], validation
  end
  
  def test_should_pass_block_through_to_class
    options = {}
    condition_proxy = StateMachine::ConditionProxy.new(Validateable, lambda {})
    
    proxy_block = lambda {}
    validation = condition_proxy.validate(:name, options, &proxy_block)
    
    assert_equal [:name, options, proxy_block], validation
  end
  
  def test_should_pass_object_into_proxy_condition
    condition_args = []
    condition_proxy = StateMachine::ConditionProxy.new(Validateable, lambda {|*args| condition_args = args})
    options = condition_proxy.validate[0]
    
    object = Validateable.new
    options[:if].call(object)
    
    assert_equal [object], condition_args
  end
  
  def test_should_evaluate_symbol_condition
    klass = Class.new(Validateable) do
      attr_accessor :callback_called
      
      def callback
        @callback_called = true
      end
    end
    
    condition_proxy = StateMachine::ConditionProxy.new(klass, :callback)
    options = condition_proxy.validate[0]
    
    object = klass.new
    options[:if].call(object)
    
    assert object.callback_called
  end
  
  def test_should_evaluate_string_condition
    klass = Class.new(Validateable) do
      attr_accessor :callback_called
    end
    
    condition_proxy = StateMachine::ConditionProxy.new(klass, '@callback_called = true')
    options = condition_proxy.validate[0]
    
    object = klass.new
    options[:if].call(object)
    
    assert object.callback_called
  end
end

class ConditionProxyWithoutConditionsTest < Test::Unit::TestCase
  def setup
    @proxy_result = nil
    condition_proxy = StateMachine::ConditionProxy.new(Validateable, lambda {@proxy_result})
    
    @object = Validateable.new
    @options = condition_proxy.validate[0]
  end
  
  def test_should_have_options_configuration
    assert_instance_of Hash, @options
  end
  
  def test_should_have_if_option
    assert_not_nil @options[:if]
  end
  
  def test_should_be_false_if_proxy_condition_is_false
    @proxy_result = false
    assert !@options[:if].call(@object)
  end
  
  def test_should_be_true_if_proxy_condition_is_true
    @proxy_result = true
    assert @options[:if].call(@object)
  end
  
  def test_should_be_true_if_proxy_condition_is_not_true
    @proxy_result = 1
    assert @options[:if].call(@object)
  end
end

class ConditionProxyWithIfConditionTest < Test::Unit::TestCase
  def setup
    @proxy_result = nil
    condition_proxy = StateMachine::ConditionProxy.new(Validateable, lambda {@proxy_result})
    
    @object = Validateable.new
    
    @condition_result = nil
    @options = condition_proxy.validate(:if => lambda {@condition_result})[0]
  end
  
  def test_should_have_if_option
    assert_not_nil @options[:if]
  end
  
  def test_should_be_false_if_proxy_condition_is_false
    @proxy_result = false
    assert !@options[:if].call(@object)
  end
  
  def test_should_be_false_if_original_condition_is_false
    @condition_result = false
    assert !@options[:if].call(@object)
  end
  
  def test_should_be_true_if_proxy_and_original_condition_are_true
    @proxy_result = true
    @condition_result = true
    assert @options[:if].call(@object)
  end
  
  def test_should_evaluate_symbol_condition
    klass = Class.new(Validateable) do
      attr_accessor :callback
    end
    
    condition_proxy = StateMachine::ConditionProxy.new(klass, lambda {true})
    options = condition_proxy.validate(:if => :callback)[0]
    
    object = klass.new
    object.callback = false
    assert !options[:if].call(object)
    
    object.callback = true
    assert options[:if].call(object)
  end
  
  def test_should_evaluate_string_condition
    klass = Class.new(Validateable) do
      attr_accessor :callback
    end
    
    condition_proxy = StateMachine::ConditionProxy.new(klass, lambda {true})
    options = condition_proxy.validate(:if => '@callback')[0]
    
    object = klass.new
    object.callback = false
    assert !options[:if].call(object)
    
    object.callback = true
    assert options[:if].call(object)
  end
end

class ConditionProxyWithMultipleIfConditionsTest < Test::Unit::TestCase
  def setup
    condition_proxy = StateMachine::ConditionProxy.new(Validateable, lambda {true})
    
    @object = Validateable.new
    
    @first_condition_result = nil
    @second_condition_result = nil
    @options = condition_proxy.validate(:if => [lambda {@first_condition_result}, lambda {@second_condition_result}])[0]
  end
  
  def test_should_be_true_if_all_conditions_are_true
    @first_condition_result = true
    @second_condition_result = true
    assert @options[:if].call(@object)
  end
  
  def test_should_be_false_if_any_condition_is_false
    @first_condition_result = true
    @second_condition_result = false
    assert !@options[:if].call(@object)
    
    @first_condition_result = false
    @second_condition_result = true
    assert !@options[:if].call(@object)
  end
end

class ConditionProxyWithUnlessConditionTest < Test::Unit::TestCase
  def setup
    @proxy_result = nil
    condition_proxy = StateMachine::ConditionProxy.new(Validateable, lambda {@proxy_result})
    
    @object = Validateable.new
    
    @condition_result = nil
    @options = condition_proxy.validate(:unless => lambda {@condition_result})[0]
  end
  
  def test_should_have_if_option
    assert_not_nil @options[:if]
  end
  
  def test_should_be_false_if_proxy_condition_is_false
    @proxy_result = false
    assert !@options[:if].call(@object)
  end
  
  def test_should_be_false_if_original_condition_is_true
    @condition_result = true
    assert !@options[:if].call(@object)
  end
  
  def test_should_be_true_if_proxy_is_true_and_original_condition_is_false
    @proxy_result = true
    @condition_result = false
    assert @options[:if].call(@object)
  end
  
  def test_should_evaluate_symbol_condition
    klass = Class.new(Validateable) do
      attr_accessor :callback
    end
    
    condition_proxy = StateMachine::ConditionProxy.new(klass, lambda {true})
    options = condition_proxy.validate(:unless => :callback)[0]
    
    object = klass.new
    object.callback = true
    assert !options[:if].call(object)
    
    object.callback = false
    assert options[:if].call(object)
  end
  
  def test_should_evaluate_string_condition
    klass = Class.new(Validateable) do
      attr_accessor :callback
    end
    
    condition_proxy = StateMachine::ConditionProxy.new(klass, lambda {true})
    options = condition_proxy.validate(:unless => '@callback')[0]
    
    object = klass.new
    object.callback = true
    assert !options[:if].call(object)
    
    object.callback = false
    assert options[:if].call(object)
  end
end

class ConditionProxyWithMultipleUnlessConditionsTest < Test::Unit::TestCase
  def setup
    condition_proxy = StateMachine::ConditionProxy.new(Validateable, lambda {true})
    
    @object = Validateable.new
    
    @first_condition_result = nil
    @second_condition_result = nil
    @options = condition_proxy.validate(:unless => [lambda {@first_condition_result}, lambda {@second_condition_result}])[0]
  end
  
  def test_should_be_true_if_all_conditions_are_false
    @first_condition_result = false
    @second_condition_result = false
    assert @options[:if].call(@object)
  end
  
  def test_should_be_false_if_any_condition_is_true
    @first_condition_result = true
    @second_condition_result = false
    assert !@options[:if].call(@object)
    
    @first_condition_result = false
    @second_condition_result = true
    assert !@options[:if].call(@object)
  end
end

class ConditionProxyWithIfAndUnlessConditionsTest < Test::Unit::TestCase
  def setup
    condition_proxy = StateMachine::ConditionProxy.new(Validateable, lambda {true})
    
    @object = Validateable.new
    
    @if_condition_result = nil
    @unless_condition_result = nil
    @options = condition_proxy.validate(:if => lambda {@if_condition_result}, :unless => lambda {@unless_condition_result})[0]
  end
  
  def test_should_be_false_if_if_condition_is_false
    @if_condition_result = false
    @unless_condition_result = false
    assert !@options[:if].call(@object)
    
    @if_condition_result = false
    @unless_condition_result = true
    assert !@options[:if].call(@object)
  end
  
  def test_should_be_false_if_unless_condition_is_true
    @if_condition_result = false
    @unless_condition_result = true
    assert !@options[:if].call(@object)
    
    @if_condition_result = true
    @unless_condition_result = true
    assert !@options[:if].call(@object)
  end
  
  def test_should_be_true_if_if_condition_is_true_and_unless_condition_is_false
    @if_condition_result = true
    @unless_condition_result = false
    assert @options[:if].call(@object)
  end
end
