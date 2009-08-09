require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StateByDefaultTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @state = StateMachine::State.new(@machine, :parked)
  end
  
  def test_should_have_a_machine
    assert_equal @machine, @state.machine
  end
  
  def test_should_have_a_name
    assert_equal :parked, @state.name
  end
  
  def test_should_have_a_qualified_name
    assert_equal :parked, @state.name
  end
  
  def test_should_use_stringify_the_name_as_the_value
    assert_equal 'parked', @state.value
  end
  
  def test_should_not_be_initial
    assert !@state.initial
  end
  
  def test_should_not_have_a_matcher
    assert_nil @state.matcher
  end
  
  def test_should_not_have_any_methods
    expected = {}
    assert_equal expected, @state.methods
  end
end

class StateTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @state = StateMachine::State.new(@machine, :parked)
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    exception = assert_raise(ArgumentError) {StateMachine::State.new(@machine, :parked, :invalid => true)}
    assert_equal 'Invalid key(s): invalid', exception.message
  end
  
  def test_should_allow_changing_machine
    new_machine = StateMachine::Machine.new(Class.new)
    @state.machine = new_machine
    assert_equal new_machine, @state.machine
  end
  
  def test_should_allow_changing_value
    @state.value = 1
    assert_equal 1, @state.value
  end
  
  def test_should_allow_changing_initial
    @state.initial = true
    assert @state.initial
  end
  
  def test_should_allow_changing_matcher
    matcher = lambda {}
    @state.matcher = matcher
    assert_equal matcher, @state.matcher
  end
  
  def test_should_use_pretty_inspect
    assert_equal '#<StateMachine::State name=:parked value="parked" initial=false context=[]>', @state.inspect
  end
end

class StateWithoutNameTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @state = StateMachine::State.new(@machine, nil)
  end
  
  def test_should_have_a_nil_name
    assert_nil @state.name
  end
  
  def test_should_have_a_nil_qualified_name
    assert_nil @state.qualified_name
  end
  
  def test_should_have_a_nil_value
    assert_nil @state.value
  end
  
  def test_should_not_redefine_nil_predicate
    object = @klass.new
    assert !object.nil?
    assert !object.respond_to?('?')
  end
  
  def test_should_have_a_description
    assert_equal 'nil', @state.description
  end
end

class StateWithNameTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @state = StateMachine::State.new(@machine, :parked)
  end
  
  def test_should_have_a_name
    assert_equal :parked, @state.name
  end
  
  def test_should_have_a_qualified_name
    assert_equal :parked, @state.name
  end
  
  def test_should_use_stringify_the_name_as_the_value
    assert_equal 'parked', @state.value
  end
  
  def test_should_match_stringified_name
    assert @state.matches?('parked')
    assert !@state.matches?('idling')
  end
  
  def test_should_not_include_value_in_description
    assert_equal 'parked', @state.description
  end
  
  def test_should_define_predicate
    assert @klass.new.respond_to?(:parked?)
  end
end

class StateWithNilValueTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @state = StateMachine::State.new(@machine, :parked, :value => nil)
  end
  
  def test_should_have_a_name
    assert_equal :parked, @state.name
  end
  
  def test_should_have_a_nil_value
    assert_nil @state.value
  end
  
  def test_should_match_nil_values
    assert @state.matches?(nil)
  end
  
  def test_should_have_a_description
    assert_equal 'parked (nil)', @state.description
  end
  
  def test_should_define_predicate
    object = @klass.new
    assert object.respond_to?(:parked?)
  end
end

class StateWithSymbolicValueTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @state = StateMachine::State.new(@machine, :parked, :value => :parked)
  end
  
  def test_should_use_custom_value
    assert_equal :parked, @state.value
  end
    
  def test_should_not_include_value_in_description
    assert_equal 'parked', @state.description
  end
  
  def test_should_match_symbolic_value
    assert @state.matches?(:parked)
    assert !@state.matches?('parked')
  end
  
  def test_should_define_predicate
    object = @klass.new
    assert object.respond_to?(:parked?)
  end
end

class StateWithIntegerValueTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @state = StateMachine::State.new(@machine, :parked, :value => 1)
  end
  
  def test_should_use_custom_value
    assert_equal 1, @state.value
  end
  
  def test_should_include_value_in_description
    assert_equal 'parked (1)', @state.description
  end
  
  def test_should_match_integer_value
    assert @state.matches?(1)
    assert !@state.matches?(2)
  end
  
  def test_should_define_predicate
    object = @klass.new
    assert object.respond_to?(:parked?)
  end
end

class StateWithLambdaValueTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @args = nil
    @machine = StateMachine::Machine.new(@klass)
    @value = lambda {|*args| @args = args; :parked}
    @state = StateMachine::State.new(@machine, :parked, :value => @value)
  end
  
  def test_should_use_evaluated_value_by_default
    assert_equal :parked, @state.value
  end
  
  def test_should_allow_access_to_original_value
    assert_equal @value, @state.value(false)
  end
  
  def test_should_include_masked_value_in_description
    assert_equal 'parked (*)', @state.description
  end
  
  def test_should_not_pass_in_any_arguments
    @state.value
    assert_equal [], @args
  end
  
  def test_should_define_predicate
    object = @klass.new
    assert object.respond_to?(:parked?)
  end
  
  def test_should_match_evaluated_value
    assert @state.matches?(:parked)
  end
end

class StateWithCachedLambdaValueTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @dynamic_value = lambda {'value'}
    @machine.states << @state = StateMachine::State.new(@machine, :parked, :value => @dynamic_value, :cache => true)
  end
  
  def test_should_be_caching
    assert @state.cache
  end
  
  def test_should_evaluate_value
    assert_equal 'value', @state.value
  end
  
  def test_should_only_evaluate_value_once
    value = @state.value
    assert_same value, @state.value
  end
  
  def test_should_update_value_index_for_state_collection
    @state.value
    assert_equal @state, @machine.states['value', :value]
    assert_nil @machine.states[@dynamic_value, :value]
  end
end

class StateWithoutCachedLambdaValueTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @dynamic_value = lambda {'value'}
    @machine.states << @state = StateMachine::State.new(@machine, :parked, :value => @dynamic_value)
  end
  
  def test_should_not_be_caching
    assert !@state.cache
  end
  
  def test_should_evaluate_value_each_time
    value = @state.value
    assert_not_same value, @state.value
  end
  
  def test_should_not_update_value_index_for_state_collection
    @state.value
    assert_nil @machine.states['value', :value]
    assert_equal @state, @machine.states[@dynamic_value, :value]
  end
end

class StateWithMatcherTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @args = nil
    @machine = StateMachine::Machine.new(@klass)
    @state = StateMachine::State.new(@machine, :parked, :if => lambda {|value| value == 1})
  end
  
  def test_should_not_match_actual_value
    assert !@state.matches?('parked')
  end
  
  def test_should_match_evaluated_block
    assert @state.matches?(1)
  end
end

class StateInitialTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @state = StateMachine::State.new(@machine, :parked, :initial => true)
  end
  
  def test_should_be_initial
    assert @state.initial
    assert @state.initial?
  end
end

class StateNotInitialTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @state = StateMachine::State.new(@machine, :parked, :initial => false)
  end
  
  def test_should_not_be_initial
    assert !@state.initial
    assert !@state.initial?
  end
end

class StateFinalTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @state = StateMachine::State.new(@machine, :parked)
  end
  
  def test_should_be_final_without_input_transitions
    assert @state.final?
  end
  
  def test_should_be_final_with_input_transitions
    @machine.event :park do
      transition :idling => :parked
    end
    
    assert @state.final?
  end
  
  def test_should_be_final_with_loopback
    @machine.event :ignite do
      transition :parked => same
    end
    
    assert @state.final?
  end
end

class StateNotFinalTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @state = StateMachine::State.new(@machine, :parked)
  end
  
  def test_should_not_be_final_with_outgoing_whitelist_transitions
    @machine.event :ignite do
      transition :parked => :idling
    end
    
    assert !@state.final?
  end
  
  def test_should_not_be_final_with_outgoing_all_transitions
    @machine.event :ignite do
      transition all => :idling
    end
    
    assert !@state.final?
  end
  
  def test_should_not_be_final_with_outgoing_blacklist_transitions
    @machine.event :ignite do
      transition all - :first_gear => :idling
    end
    
    assert !@state.final?
  end
end

class StateWithConflictingHelpersTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def parked?
        0
      end
    end
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked
    @object = @klass.new
  end
  
  def test_should_not_redefine_state_predicate
    assert_equal 0, @object.parked?
  end
  
  def test_should_allow_super_chaining
    @klass.class_eval do
      def parked?
        super ? 1 : 0
      end
    end
    
    assert_equal 0, @object.parked?
  end
end

class StateWithNamespaceTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :namespace => 'alarm')
    @state = StateMachine::State.new(@machine, :active)
    @object = @klass.new
  end
  
  def test_should_have_a_name
    assert_equal :active, @state.name
  end
  
  def test_should_have_a_qualified_name
    assert_equal :alarm_active, @state.qualified_name
  end
  
  def test_should_namespace_predicate
    assert @object.respond_to?(:alarm_active?)
  end
end

class StateAfterBeingCopiedTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @state = StateMachine::State.new(@machine, :parked)
    @copied_state = @state.dup
  end
  
  def test_should_not_have_the_same_collection_of_methods
    assert_not_same @state.methods, @copied_state.methods
  end
end

class StateWithContextTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @ancestors = @klass.ancestors
    @state = StateMachine::State.new(@machine, :idling)
    
    speed_method = nil
    rpm_method = nil
    @state.context do
      def speed
        0
      end
      speed_method = instance_method(:speed)
      
      def rpm
        1000
      end
      rpm_method = instance_method(:rpm)
    end
    
    @speed_method = speed_method
    @rpm_method = rpm_method
  end
  
  def test_should_include_new_module_in_owner_class
    assert_not_equal @ancestors, @klass.ancestors
    assert_equal 1, @klass.ancestors.size - @ancestors.size
  end
  
  def test_should_define_each_context_method_in_owner_class
    %w(speed rpm).each {|method| assert @klass.method_defined?(method)}
  end
  
  def test_should_not_use_context_methods_as_owner_class_methods
    assert_not_equal @speed_method, @klass.instance_method(:speed)
    assert_not_equal @rpm_method, @klass.instance_method(:rpm)
  end
  
  def test_should_include_context_methods_in_state_methods
    assert_equal @speed_method, @state.methods[:speed]
    assert_equal @rpm_method, @state.methods[:rpm]
  end
end

class StateWithMultipleContextsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @ancestors = @klass.ancestors
    @state = StateMachine::State.new(@machine, :idling)
    
    speed_method = nil
    @state.context do
      def speed
        0
      end
      
      speed_method = instance_method(:speed)
    end
    @speed_method = speed_method
    
    rpm_method = nil
    @state.context do
      def rpm
        1000
      end
      
      rpm_method = instance_method(:rpm)
    end
    @rpm_method = rpm_method
  end
  
  def test_should_include_new_module_in_owner_class
    assert_not_equal @ancestors, @klass.ancestors
    assert_equal 2, @klass.ancestors.size - @ancestors.size
  end
  
  def test_should_define_each_context_method_in_owner_class
    %w(speed rpm).each {|method| assert @klass.method_defined?(method)}
  end
  
  def test_should_not_use_context_methods_as_owner_class_methods
    assert_not_equal @speed_method, @klass.instance_method(:speed)
    assert_not_equal @rpm_method, @klass.instance_method(:rpm)
  end
  
  def test_should_include_context_methods_in_state_methods
    assert_equal @speed_method, @state.methods[:speed]
    assert_equal @rpm_method, @state.methods[:rpm]
  end
end

class StateWithExistingContextMethodTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def speed
        60
      end
    end
    @original_speed_method = @klass.instance_method(:speed)
    
    @machine = StateMachine::Machine.new(@klass)
    @state = StateMachine::State.new(@machine, :idling)
    @state.context do
      def speed
        0
      end
    end
  end
  
  def test_should_not_override_method
    assert_equal @original_speed_method, @klass.instance_method(:speed)
  end
end

class StateWithRedefinedContextMethodTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @state = StateMachine::State.new(@machine, 'on')
    
    old_speed_method = nil
    @state.context do
      def speed
        0
      end
      old_speed_method = instance_method(:speed)
    end
    @old_speed_method = old_speed_method
    
    current_speed_method = nil
    @state.context do
      def speed
        'green'
      end
      current_speed_method = instance_method(:speed)
    end
    @current_speed_method = current_speed_method
  end
  
  def test_should_track_latest_defined_method
    assert_equal @current_speed_method, @state.methods[:speed]
  end
end

class StateWithInvalidMethodCallTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @ancestors = @klass.ancestors
    @state = StateMachine::State.new(@machine, :idling)
    @state.context do
      def speed
        0
      end
    end
    
    @object = @klass.new
  end
  
  def test_should_raise_an_exception
    exception = assert_raise(NoMethodError) { @state.call(@object, :invalid) }
    assert_equal "undefined method 'invalid' for #{@object} with idling state", exception.message
  end
end

class StateWithValidMethodCallTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @ancestors = @klass.ancestors
    @state = StateMachine::State.new(@machine, :idling)
    @state.context do
      def speed(arg = nil)
        block_given? ? [arg, yield] : arg
      end
    end
    
    @object = @klass.new
  end
  
  def test_should_not_raise_an_exception
    assert_nothing_raised { @state.call(@object, :speed) }
  end
  
  def test_should_pass_arguments_through
    assert_equal 1, @state.call(@object, :speed, 1)
  end
  
  def test_should_pass_blocks_through
    assert_equal [nil, 1], @state.call(@object, :speed) {1}
  end
  
  def test_should_pass_both_arguments_and_blocks_through
    assert_equal [1, 2], @state.call(@object, :speed, 1) {2}
  end
end

begin
  # Load library
  require 'rubygems'
  require 'graphviz'
  
  class StateDrawingTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      @machine.event :ignite do
        transition :parked => :idling
      end
      @state = StateMachine::State.new(@machine, :parked, :value => 1)
      
      graph = GraphViz.new('G')
      @node = @state.draw(graph)
    end
    
    def test_should_use_ellipse_shape
      assert_equal 'ellipse', @node['shape']
    end
    
    def test_should_set_width_to_one
      assert_equal '1', @node['width']
    end
    
    def test_should_set_height_to_one
      assert_equal '1', @node['height']
    end
    
    def test_should_use_stringified_name_as_name
      assert_equal 'parked', @node.name
    end
    
    def test_should_use_description_as_label
      assert_equal 'parked (1)', @node['label']
    end
  end
  
  class StateDrawingInitialTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      @machine.event :ignite do
        transition :parked => :idling
      end
      @state = StateMachine::State.new(@machine, :parked, :initial => true)
      
      @graph = GraphViz.new('G')
      @node = @state.draw(@graph)
    end
    
    def test_should_use_ellipse_as_shape
      assert_equal 'ellipse', @node['shape']
    end
    
    def test_should_draw_edge_between_point_and_state
      assert_equal 2, @graph.node_count
      assert_equal 1, @graph.edge_count
    end
  end
  
  class StateDrawingNilNameTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      @state = StateMachine::State.new(@machine, nil)
      
      graph = GraphViz.new('G')
      @node = @state.draw(graph)
    end
    
    def test_should_use_stringified_nil_as_name
      assert_equal 'nil', @node.name
    end
    
    def test_should_use_description_as_label
      assert_equal 'nil', @node['label']
    end
  end
  
  class StateDrawingLambdaValueTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      @state = StateMachine::State.new(@machine, :parked, :value => lambda {})
      
      graph = GraphViz.new('G')
      @node = @state.draw(graph)
    end
    
    def test_should_use_stringified_name_as_name
      assert_equal 'parked', @node.name
    end
    
    def test_should_use_description_as_label
      assert_equal 'parked (*)', @node['label']
    end
  end
  
  class StateDrawingNonFinalTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      @machine.event :ignite do
        transition :parked => :idling
      end
      @state = StateMachine::State.new(@machine, :parked)
      
      graph = GraphViz.new('G')
      @node = @state.draw(graph)
    end
    
    def test_should_use_ellipse_as_shape
      assert_equal 'ellipse', @node['shape']
    end
  end
  
  class StateDrawingFinalTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      @state = StateMachine::State.new(@machine, :parked)
      
      graph = GraphViz.new('G')
      @node = @state.draw(graph)
    end
    
    def test_should_use_doublecircle_as_shape
      assert_equal 'doublecircle', @node['shape']
    end
  end
rescue LoadError
  $stderr.puts 'Skipping GraphViz StateMachine::State tests. `gem install ruby-graphviz` and try again.'
end
