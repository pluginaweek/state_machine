require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class EvalHelpersTest < Test::Unit::TestCase
  include StateMachine::EvalHelpers
  
  def setup
    @object = Object.new
  end
  
  def test_should_raise_exception_if_method_is_not_symbol_string_or_proc
    exception = assert_raise(ArgumentError) { evaluate_method(@object, 1) }
    assert_match /Methods must/, exception.message
  end
end

class EvalHelpersSymbolTest < Test::Unit::TestCase
  include StateMachine::EvalHelpers
  
  def setup
    class << (@object = Object.new)
      def callback
        true
      end
    end
  end
  
  def test_should_call_method_on_object_with_no_arguments
    assert evaluate_method(@object, :callback, 1, 2, 3)
  end
end

class EvalHelpersSymbolWithArgumentsTest < Test::Unit::TestCase
  include StateMachine::EvalHelpers
  
  def setup
    class << (@object = Object.new)
      def callback(*args)
        args
      end
    end
  end
  
  def test_should_call_method_with_all_arguments
    assert_equal [1, 2, 3], evaluate_method(@object, :callback, 1, 2, 3)
  end
end

class EvalHelpersStringTest < Test::Unit::TestCase
  include StateMachine::EvalHelpers
  
  def setup
    @object = Object.new
  end
  
  def test_should_evaluate_string
    assert_equal 1, evaluate_method(@object, '1')
  end
  
  def test_should_evaluate_string_within_object_context
    @object.instance_variable_set('@value', 1)
    assert_equal 1, evaluate_method(@object, '@value')
  end
  
  def test_should_ignore_additional_arguments
    assert_equal 1, evaluate_method(@object, '1', 2, 3, 4)
  end
end

class EvalHelpersProcTest < Test::Unit::TestCase
  include StateMachine::EvalHelpers
  
  def setup
    @object = Object.new
    @proc = lambda {|obj| obj}
  end
  
  def test_should_call_proc_with_object_as_argument
    assert_equal @object, evaluate_method(@object, @proc, 1, 2, 3)
  end
end

class EvalHelpersProcWithoutArgumentsTest < Test::Unit::TestCase
  include StateMachine::EvalHelpers
  
  def setup
    @object = Object.new
    @proc = lambda {|*args| args}
    class << @proc
      def arity
        0
      end
    end
  end
  
  def test_should_call_proc_with_no_arguments
    assert_equal [], evaluate_method(@object, @proc, 1, 2, 3)
  end
end

class EvalHelpersProcWithArgumentsTest < Test::Unit::TestCase
  include StateMachine::EvalHelpers
  
  def setup
    @object = Object.new
    @proc = lambda {|*args| args}
  end
  
  def test_should_call_method_with_all_arguments
    assert_equal [@object, 1, 2, 3], evaluate_method(@object, @proc, 1, 2, 3)
  end
end
