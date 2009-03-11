require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MachineByDefaultTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @object = @klass.new
  end
  
  def test_should_have_an_owner_class
    assert_equal @klass, @machine.owner_class
  end
  
  def test_should_have_an_attribute
    assert_equal :state, @machine.attribute
  end
  
  def test_should_have_an_initial_state
    assert_not_nil @machine.initial_state(@object)
  end
  
  def test_should_have_a_nil_initial_state
    assert_nil @machine.initial_state(@object).value
  end
  
  def test_should_not_have_any_events
    assert !@machine.events.any?
  end
  
  def test_should_not_have_any_before_callbacks
    assert @machine.callbacks[:before].empty?
  end
  
  def test_should_not_have_any_after_callbacks
    assert @machine.callbacks[:after].empty?
  end
  
  def test_should_not_have_an_action
    assert_nil @machine.action
  end
  
  def test_should_not_have_a_namespace
    assert_nil @machine.namespace
  end
  
  def test_should_have_a_nil_state
    assert_equal [nil], @machine.states.keys
  end
  
  def test_should_set_initial_on_nil_state
    assert @machine.state(nil).initial
  end
  
  def test_should_not_be_extended_by_the_active_record_integration
    assert !(class << @machine; ancestors; end).include?(StateMachine::Integrations::ActiveRecord)
  end
  
  def test_should_not_be_extended_by_the_datamapper_integration
    assert !(class << @machine; ancestors; end).include?(StateMachine::Integrations::DataMapper)
  end
  
  def test_should_not_be_extended_by_the_sequel_integration
    assert !(class << @machine; ancestors; end).include?(StateMachine::Integrations::Sequel)
  end
  
  def test_should_define_a_reader_attribute_for_the_attribute
    assert @object.respond_to?(:state)
  end
  
  def test_should_define_a_writer_attribute_for_the_attribute
    assert @object.respond_to?(:state=)
  end
  
  def test_should_define_a_predicate_for_the_attribute
    assert @object.respond_to?(:state?)
  end
  
  def test_should_define_a_name_reader_for_the_attribute
    assert @object.respond_to?(:state_name)
  end
  
  def test_should_not_define_singular_with_scope
    assert !@klass.respond_to?(:with_state)
  end
  
  def test_should_not_define_singular_without_scope
    assert !@klass.respond_to?(:without_state)
  end
  
  def test_should_not_define_plural_with_scope
    assert !@klass.respond_to?(:with_states)
  end
  
  def test_should_not_define_plural_without_scope
    assert !@klass.respond_to?(:without_states)
  end
  
  def test_should_extend_owner_class_with_class_methods
    assert (class << @klass; ancestors; end).include?(StateMachine::ClassMethods)
  end
  
  def test_should_include_instance_methods_in_owner_class
    assert @klass.included_modules.include?(StateMachine::InstanceMethods)
  end
  
  def test_should_define_state_machines_reader
    expected = {:state => @machine}
    assert_equal expected, @klass.state_machines
  end
end

class MachineWithCustomAttributeTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :status)
    @object = @klass.new
  end
  
  def test_should_use_custom_attribute
    assert_equal :status, @machine.attribute
  end
  
  def test_should_define_a_reader_attribute_for_the_attribute
    assert @object.respond_to?(:status)
  end
  
  def test_should_define_a_writer_attribute_for_the_attribute
    assert @object.respond_to?(:status=)
  end
  
  def test_should_define_a_predicate_for_the_attribute
    assert @object.respond_to?(:status?)
  end
  
  def test_should_define_a_name_reader_for_the_attribute
    assert @object.respond_to?(:status_name)
  end
end

class MachineWithStaticInitialStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def initialize(attributes = {})
        attributes.each {|attr, value| send("#{attr}=", value)}
        super()
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
  end
  
  def test_should_have_an_initial_state
    object = @klass.new
    assert_equal 'parked', @machine.initial_state(object).value
  end
  
  def test_should_set_initial_on_state_object
    assert @machine.state(:parked).initial
  end
  
  def test_should_set_initial_state_if_existing_is_nil
    object = @klass.new(:state => nil)
    assert_equal 'parked', object.state
  end
  
  def test_should_set_initial_state_if_existing_is_empty
    object = @klass.new(:state => '')
    assert_equal 'parked', object.state
  end
  
  def test_should_not_set_initial_state_if_existing_is_not_empty
    object = @klass.new(:state => 'idling')
    assert_equal 'idling', object.state
  end
  
  def test_should_be_included_in_known_states
    assert_equal [:parked], @machine.states.keys
  end
end

class MachineWithDynamicInitialStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_accessor :initial_state
    end
    @machine = StateMachine::Machine.new(@klass, :initial => lambda {|object| object.initial_state || :default})
    @machine.state :parked, :idling, :default
    @object = @klass.new
  end
  
  def test_should_use_the_record_for_determining_the_initial_state
    @object.initial_state = :parked
    assert_equal :parked, @machine.initial_state(@object).name
    
    @object.initial_state = :idling
    assert_equal :idling, @machine.initial_state(@object).name
  end
  
  def test_should_set_initial_state_on_created_object
    assert_equal 'default', @object.state
  end
  
  def test_should_not_be_included_in_known_states
    assert_equal [:parked, :idling, :default], @machine.states.map {|state| state.name}
  end
end

class MachineWithCustomActionTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new, :action => :save)
  end
  
  def test_should_use_the_custom_action
    assert_equal :save, @machine.action
  end
end

class MachineWithNilActionTest < Test::Unit::TestCase
  def setup
    integration = Module.new do
      def default_action
        :save
      end
    end
    StateMachine::Integrations.const_set('Custom', integration)
    @machine = StateMachine::Machine.new(Class.new, :action => nil, :integration => :custom)
  end
  
  def test_should_have_a_nil_action
    assert_nil @machine.action
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineWithoutIntegrationTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @object = @klass.new
  end
  
  def test_transaction_should_yield
    @yielded = false
    @machine.within_transaction(@object) do
      @yielded = true
    end
    
    assert @yielded
  end
  
  def test_invalidation_should_do_nothing
    assert_nil @machine.invalidate(@object, StateMachine::Event.new(@machine, :park))
  end
  
  def test_reset_should_do_nothing
    assert_nil @machine.reset(@object)
  end
end

class MachineWithCustomIntegrationTest < Test::Unit::TestCase
  def setup
    StateMachine::Integrations.const_set('Custom', Module.new)
    @machine = StateMachine::Machine.new(Class.new, :integration => :custom)
  end
  
  def test_should_be_extended_by_the_integration
    assert (class << @machine; ancestors; end).include?(StateMachine::Integrations::Custom)
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineWithIntegrationTest < Test::Unit::TestCase
  def setup
    @integration = Module.new do
      class << self; attr_accessor :initialized, :with_scopes, :without_scopes; end
      @initialized = false
      @with_scopes = []
      @without_scopes = []
      
      def after_initialize
        StateMachine::Integrations::Custom.initialized = true
      end
      
      def default_action
        :save
      end
      
      def create_with_scope(name)
        StateMachine::Integrations::Custom.with_scopes << name
        lambda {}
      end
      
      def create_without_scope(name)
        StateMachine::Integrations::Custom.without_scopes << name
        lambda {}
      end
    end
    
    StateMachine::Integrations.const_set('Custom', @integration)
    @machine = StateMachine::Machine.new(Class.new, :integration => :custom)
  end
  
  def test_should_call_after_initialize_hook
    assert @integration.initialized
  end
  
  def test_should_use_the_default_action
    assert_equal :save, @machine.action
  end
  
  def test_should_use_the_custom_action_if_specified
    machine = StateMachine::Machine.new(Class.new, :integration => :custom, :action => :save!)
    assert_equal :save!, machine.action
  end
  
  def test_should_define_a_singular_and_plural_with_scope
    assert_equal %w(with_state with_states), @integration.with_scopes
  end
  
  def test_should_define_a_singular_and_plural_without_scope
    assert_equal %w(without_state without_states), @integration.without_scopes
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineWithCustomPluralTest < Test::Unit::TestCase
  def setup
    @integration = Module.new do
      class << self; attr_accessor :with_scopes, :without_scopes; end
      @with_scopes = []
      @without_scopes = []
      
      def create_with_scope(name)
        StateMachine::Integrations::Custom.with_scopes << name
        lambda {}
      end
      
      def create_without_scope(name)
        StateMachine::Integrations::Custom.without_scopes << name
        lambda {}
      end
    end
    
    StateMachine::Integrations.const_set('Custom', @integration)
    @machine = StateMachine::Machine.new(Class.new, :integration => :custom, :plural => 'staties')
  end
  
  def test_should_define_a_singular_and_plural_with_scope
    assert_equal %w(with_state with_staties), @integration.with_scopes
  end
  
  def test_should_define_a_singular_and_plural_without_scope
    assert_equal %w(without_state without_staties), @integration.without_scopes
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineWithCustomInvalidationTest < Test::Unit::TestCase
  def setup
    @integration = Module.new do
      def invalidate(object, event)
        object.error = invalid_message(object, event)
      end
    end
    StateMachine::Integrations.const_set('Custom', @integration)
    
    @klass = Class.new do
      attr_accessor :error
    end
    
    @machine = StateMachine::Machine.new(@klass, :integration => :custom, :invalid_message => 'cannot %s when %s')
    @machine.state :parked
    
    @object = @klass.new
    @object.state = 'parked'
  end
  
  def test_use_custom_message
    @machine.invalidate(@object, StateMachine::Event.new(@machine, :park))
    assert_equal 'cannot park when parked', @object.error
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineTest < Test::Unit::TestCase
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {StateMachine::Machine.new(Class.new, :invalid => true)}
  end
  
  def test_should_not_raise_exception_if_custom_invalid_message_specified
    assert_nothing_raised {StateMachine::Machine.new(Class.new, :invalid_message => 'custom')}
  end
  
  def test_should_evaluate_a_block_during_initialization
    called = true
    StateMachine::Machine.new(Class.new) do
      called = respond_to?(:event)
    end
    
    assert called
  end
  
  def test_should_provide_matcher_helpers_during_initialization
    matchers = []
    
    StateMachine::Machine.new(Class.new) do
      matchers = [all, any, same]
    end
    
    assert_equal [StateMachine::AllMatcher.instance, StateMachine::AllMatcher.instance, StateMachine::LoopbackMatcher.instance], matchers
  end
end

class MachineAfterBeingCopiedTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new, :state, :initial => :parked)
    @machine.event(:ignite) {}
    @machine.before_transition(lambda {})
    @machine.after_transition(lambda {})
    
    @copied_machine = @machine.clone
  end
  
  def test_should_not_have_the_same_collection_of_states
    assert_not_same @copied_machine.states, @machine.states
  end
  
  def test_should_copy_each_state
    assert_not_same @copied_machine.states[:parked], @machine.states[:parked]
  end
  
  def test_should_update_machine_for_each_state
    assert_equal @copied_machine, @copied_machine.states[:parked].machine
  end
  
  def test_should_not_update_machine_for_original_state
    assert_equal @machine, @machine.states[:parked].machine
  end
  
  def test_should_not_have_the_same_collection_of_events
    assert_not_same @copied_machine.events, @machine.events
  end
  
  def test_should_copy_each_event
    assert_not_same @copied_machine.events[:ignite], @machine.events[:ignite]
  end
  
  def test_should_update_machine_for_each_event
    assert_equal @copied_machine, @copied_machine.events[:ignite].machine
  end
  
  def test_should_not_update_machine_for_original_event
    assert_equal @machine, @machine.events[:ignite].machine
  end
  
  def test_should_not_have_the_same_callbacks
    assert_not_same @copied_machine.callbacks, @machine.callbacks
  end
  
  def test_should_not_have_the_same_before_callbacks
    assert_not_same @copied_machine.callbacks[:before], @machine.callbacks[:before]
  end
  
  def test_should_not_have_the_same_after_callbacks
    assert_not_same @copied_machine.callbacks[:after], @machine.callbacks[:after]
  end
end

class MachineAfterChangingOwnerClassTest < Test::Unit::TestCase
  def setup
    @original_class = Class.new
    @machine = StateMachine::Machine.new(@original_class)
    
    @new_class = Class.new(@original_class)
    @new_machine = @machine.clone
    @new_machine.owner_class = @new_class
    
    @object = @new_class.new
  end
  
  def test_should_update_owner_class
    assert_equal @new_class, @new_machine.owner_class
  end
  
  def test_should_not_change_original_owner_class
    assert_equal @original_class, @machine.owner_class
  end
  
  def test_should_change_the_associated_machine_in_the_new_class
    assert_equal @new_machine, @new_class.state_machines[:state]
  end
  
  def test_should_not_change_the_associated_machine_in_the_original_class
    assert_equal @machine, @original_class.state_machines[:state]
  end
end

class MachineAfterChangingInitialState < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @machine.initial_state = :idling
    
    @object = @klass.new
  end
  
  def test_should_change_the_initial_state
    assert_equal :idling, @machine.initial_state(@object).name
  end
  
  def test_should_include_in_known_states
    assert_equal [:parked, :idling], @machine.states.map {|state| state.name}
  end
  
  def test_should_reset_original_initial_state
    assert !@machine.state(:parked).initial
  end
  
  def test_should_set_new_state_to_initial
    assert @machine.state(:idling).initial
  end
end

class MachineWithInstanceHelpersTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @object = @klass.new
  end
  
  def test_should_not_redefine_existing_public_methods
    @klass.class_eval do
      def state
        'parked'
      end
    end
    
    @machine.define_instance_method(:state) {}
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_redefine_existing_protected_methods
    @klass.class_eval do
      protected
        def state
          'parked'
        end
    end
    
    @machine.define_instance_method(:state) {}
    assert_equal 'parked', @object.send(:state)
  end
  
  def test_should_not_redefine_existing_private_methods
    @klass.class_eval do
      private
        def state
          'parked'
        end
    end
    
    @machine.define_instance_method(:state) {}
    assert_equal 'parked', @object.send(:state)
  end
  
  def test_should_define_nonexistent_methods
    @machine.define_instance_method(:state) {'parked'}
    assert_equal 'parked', @object.state
  end
end

class MachineWithClassHelpersTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
  end
  
  def test_should_not_redefine_existing_public_methods
    class << @klass
      def states
        []
      end
    end
    
    @machine.define_class_method(:states) {}
    assert_equal [], @klass.states
  end
  
  def test_should_not_redefine_existing_protected_methods
    class << @klass
      protected
        def states
          []
        end
    end
    
    @machine.define_class_method(:states) {}
    assert_equal [], @klass.send(:states)
  end
  
  def test_should_not_redefine_existing_private_methods
    class << @klass
      private
        def states
          []
        end
    end
    
    @machine.define_class_method(:states) {}
    assert_equal [], @klass.send(:states)
  end
  
  def test_should_define_nonexistent_methods
    @machine.define_class_method(:states) {[]}
    assert_equal [], @klass.states
  end
end

class MachineWithConflictingHelpersTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def self.with_state
        :with_state
      end
      
      def self.with_states
        :with_states
      end
      
      def self.without_state
        :without_state
      end
      
      def self.without_states
        :without_states
      end
      
      attr_accessor :status
      
      def state
        'parked'
      end
      
      def state=(value)
        self.status = value
      end
      
      def state?
        true
      end
      
      def state_name
        :parked
      end
    end
    
    StateMachine::Integrations.const_set('Custom', Module.new do
      def create_with_scope(name)
        lambda {|klass, values| []}
      end
      
      def create_without_scope(name)
        lambda {|klass, values| []}
      end
    end)
    
    @machine = StateMachine::Machine.new(@klass, :integration => :custom)
    @machine.state :parked, :idling
    @object = @klass.new
  end
  
  def test_should_not_redefine_singular_with_scope
    assert_equal :with_state, @klass.with_state
  end
  
  def test_should_not_redefine_plural_with_scope
    assert_equal :with_states, @klass.with_states
  end
  
  def test_should_not_redefine_singular_without_scope
    assert_equal :without_state, @klass.without_state
  end
  
  def test_should_not_redefine_plural_without_scope
    assert_equal :without_states, @klass.without_states
  end
  
  def test_should_not_redefine_attribute_writer
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_redefine_attribute_writer
    @object.state = 'parked'
    assert_equal 'parked', @object.status
  end
  
  def test_should_not_define_attribute_predicate
    assert @object.state?
  end
  
  def test_should_not_redefine_attribute_name_reader
    assert_equal :parked, @object.state_name
  end
  
  def test_should_allow_super_chaining
    @klass.class_eval do
      def self.with_state(*states)
        super == []
      end
      
      def self.with_states(*states)
        super == []
      end
      
      def self.without_state(*states)
        super == []
      end
      
      def self.without_states(*states)
        super == []
      end
      
      attr_accessor :status
      
      def state
        super || 'parked'
      end
      
      def state=(value)
        super
        self.status = value
      end
      
      def state?(state)
        super ? 1 : 0
      end
      
      def state_name
        super == :parked ? 1 : 0
      end
    end
    
    assert_equal true, @klass.with_state
    assert_equal true, @klass.with_states
    assert_equal true, @klass.without_state
    assert_equal true, @klass.without_states
    
    assert_equal 'parked', @object.state
    @object.state = 'idling'
    assert_equal 'idling', @object.status
    assert_equal 0, @object.state?(:parked)
    assert_equal 0, @object.state_name
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineWithoutInitializeTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @object = @klass.new
  end
  
  def test_should_initialize_state
    assert_equal 'parked', @object.state
  end
end

class MachineWithInitializeWithoutSuperTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def initialize
      end
    end
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @object = @klass.new
  end
  
  def test_should_not_initialize_state
    assert_nil @object.state
  end
end

class MachineWithInitializeAndSuperTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def initialize
        super()
      end
    end
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @object = @klass.new
  end
  
  def test_should_initialize_state
    assert_equal 'parked', @object.state
  end
end

class MachineWithInitializeArgumentsAndBlockTest < Test::Unit::TestCase
  def setup
    @superclass = Class.new do
      attr_reader :args
      attr_reader :block_given
      
      def initialize(*args)
        @args = args
        @block_given = block_given?
      end
    end
    @klass = Class.new(@superclass)
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @object = @klass.new(1, 2, 3) {}
  end
  
  def test_should_initialize_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_preserve_arguments
    assert_equal [1, 2, 3], @object.args
  end
  
  def test_should_preserve_block
    assert @object.block_given
  end
end

class MachineWithCustomInitializeTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def initialize
        initialize_state_machines
      end
    end
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @object = @klass.new
  end
  
  def test_should_initialize_state
    assert_equal 'parked', @object.state
  end
end

class MachineWithStatesTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @parked, @idling = @machine.state :parked, :idling
    
    @object = @klass.new
  end
  
  def test_should_have_states
    assert_equal [nil, :parked, :idling], @machine.states.map {|state| state.name}
  end
  
  def test_should_allow_state_lookup_by_name
    assert_equal @parked, @machine.states[:parked]
  end
  
  def test_should_allow_state_lookup_by_value
    assert_equal @parked, @machine.states['parked', :value]
  end
  
  def test_should_use_stringified_name_for_value
    assert_equal 'parked', @parked.value
  end
  
  def test_should_not_use_custom_matcher
    assert_nil @parked.matcher
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    exception = assert_raise(ArgumentError) {@machine.state(:first_gear, :invalid => true)}
    assert_equal 'Invalid key(s): invalid', exception.message
  end
  
  def test_should_not_be_in_state_if_value_does_not_match
    assert !@machine.state?(@object, :parked)
    assert !@machine.state?(@object, :idling)
  end
  
  def test_should_be_in_state_if_value_matches
    assert @machine.state?(@object, nil)
  end
  
  def test_raise_exception_if_checking_invalid_state
    assert_raise(ArgumentError) { @machine.state?(@object, :invalid) }
  end
  
  def test_should_find_state_for_object_if_value_is_known
    @object.state = 'parked'
    assert_equal @parked, @machine.state_for(@object)
  end
  
  def test_should_raise_exception_if_finding_state_for_object_with_unknown_value
    @object.state = 'invalid'
    exception = assert_raise(ArgumentError) { @machine.state_for(@object) }
    assert_equal '"invalid" is not a known state value', exception.message
  end
end

class MachineWithStatesWithCustomValuesTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @state = @machine.state :parked, :value => 1
    
    @object = @klass.new
    @object.state = 1
  end
  
  def test_should_use_custom_value
    assert_equal 1, @state.value
  end
  
  def test_should_allow_lookup_by_custom_value
    assert_equal @state, @machine.states[1, :value]
  end
  
  def test_should_be_in_state_if_value_matches
    assert @machine.state?(@object, :parked)
  end
  
  def test_should_not_be_in_state_if_value_does_not_match
    @object.state = 2
    assert !@machine.state?(@object, :parked)
  end
  
  def test_should_find_state_for_object_if_value_is_known
    assert_equal @state, @machine.state_for(@object)
  end
end

class MachineWithStateWithMatchersTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @state = @machine.state :parked, :if => lambda {|value| !value.nil?}
    
    @object = @klass.new
    @object.state = 1
  end
  
  def test_should_use_custom_matcher
    assert_not_nil @state.matcher
    assert @state.matches?(1)
    assert !@state.matches?(nil)
  end
  
  def test_should_be_in_state_if_value_matches
    assert @machine.state?(@object, :parked)
  end
  
  def test_should_not_be_in_state_if_value_does_not_match
    @object.state = nil
    assert !@machine.state?(@object, :parked)
  end
  
  def test_should_find_state_for_object_if_value_is_known
    assert_equal @state, @machine.state_for(@object)
  end
end

class MachineWithStatesWithBehaviorsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    
    @parked, @idling = @machine.state :parked, :idling do
      def speed
        0
      end
    end
  end
  
  def test_should_define_behaviors_for_each_state
    assert_not_nil @parked.methods[:speed]
    assert_not_nil @idling.methods[:speed]
  end
  
  def test_should_define_different_behaviors_for_each_state
    assert_not_equal @parked.methods[:speed], @idling.methods[:speed]
  end
end

class MachineWithExistingStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @state = @machine.state :parked
    @same_state = @machine.state :parked, :value => 1
  end
  
  def test_should_not_create_a_new_state
    assert_same @state, @same_state
  end
  
  def test_should_update_attributes
    assert_equal 1, @state.value
  end
  
  def test_should_no_longer_be_able_to_look_up_state_by_original_value
    assert_nil @machine.states['parked', :value]
  end
  
  def test_should_be_able_to_look_up_state_by_new_value
    assert_equal @state, @machine.states[1, :value]
  end
end

class MachineWithOtherStates < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @parked, @idling = @machine.other_states(:parked, :idling)
  end
  
  def test_should_include_other_states_in_known_states
    assert_equal [@parked, @idling], @machine.states.to_a
  end
  
  def test_should_use_default_value
    assert_equal 'idling', @idling.value
  end
  
  def test_should_not_create_matcher
    assert_nil @idling.matcher
  end
end

class MachineWithEventsTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
  end
  
  def test_should_return_the_created_event
    assert_instance_of StateMachine::Event, @machine.event(:ignite)
  end
  
  def test_should_create_event_with_given_name
    event = @machine.event(:ignite) {}
    assert_equal :ignite, event.name
  end
  
  def test_should_evaluate_block_within_event_context
    responded = false
    @machine.event :ignite do
      responded = respond_to?(:transition)
    end
    
    assert responded
  end
  
  def test_should_be_aliased_as_on
    event = @machine.on(:ignite) {}
    assert_equal :ignite, event.name
  end
  
  def test_should_have_events
    event = @machine.event(:ignite)
    assert_equal [event], @machine.events.to_a
  end
end

class MachineWithExistingEventTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new)
    @event = @machine.event(:ignite)
    @same_event = @machine.event(:ignite)
  end
  
  def test_should_not_create_new_event
    assert_same @event, @same_event
  end
  
  def test_should_allow_accessing_event_without_block
    assert_equal @event, @machine.event(:ignite)
  end
end

class MachineWithEventsWithTransitionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @event = @machine.event(:ignite) do
      transition :parked => :idling
      transition :stalled => :idling
    end
  end
  
  def test_should_have_events
    assert_equal [@event], @machine.events.to_a
  end
  
  def test_should_track_states_defined_in_event_transitions
    assert_equal [:parked, :idling, :stalled], @machine.states.map {|state| state.name}
  end
  
  def test_should_not_duplicate_states_defined_in_multiple_event_transitions
    @machine.event :park do
      transition :idling => :parked
    end
    
    assert_equal [:parked, :idling, :stalled], @machine.states.map {|state| state.name}
  end
  
  def test_should_track_state_from_new_events
    @machine.event :shift_up do
      transition :idling => :first_gear
    end
    
    assert_equal [:parked, :idling, :stalled, :first_gear], @machine.states.map {|state| state.name}
  end
end

class MachineWithMultipleEventsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @park, @shift_down = @machine.event(:park, :shift_down) do
      transition :first_gear => :parked
    end
  end
  
  def test_should_have_events
    assert_equal [@park, @shift_down], @machine.events.to_a
  end
  
  def test_should_define_transitions_for_each_event
    [@park, @shift_down].each {|event| assert_equal 1, event.guards.size}
  end
  
  def test_should_transition_the_same_for_each_event
    object = @klass.new
    object.state = 'first_gear'
    object.park
    assert_equal 'parked', object.state
    
    object = @klass.new
    object.state = 'first_gear'
    object.shift_down
    assert_equal 'parked', object.state
  end
end

class MachineWithTransitionCallbacksTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_accessor :callbacks
    end
    
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @event = @machine.event :ignite do
      transition :parked => :idling
    end
    
    @object = @klass.new
    @object.callbacks = []
  end
  
  def test_should_not_raise_exception_if_implicit_option_specified
    assert_nothing_raised {@machine.before_transition :invalid => true, :do => lambda {}}
  end
  
  def test_should_raise_exception_if_do_option_not_specified
    exception = assert_raise(ArgumentError) {@machine.before_transition :to => :idling}
    assert_equal ':do callback must be specified', exception.message
  end
  
  def test_should_invoke_callbacks_during_transition
    @machine.before_transition lambda {|object| object.callbacks << 'before'}
    @machine.after_transition lambda {|object| object.callbacks << 'after'}
    
    @event.fire(@object)
    assert_equal %w(before after), @object.callbacks
  end
  
  def test_should_support_from_requirement
    @machine.before_transition :from => :parked, :do => lambda {|object| object.callbacks << :parked}
    @machine.before_transition :from => :idling, :do => lambda {|object| object.callbacks << :idling}
    
    @event.fire(@object)
    assert_equal [:parked], @object.callbacks
  end
  
  def test_should_support_except_from_requirement
    @machine.before_transition :except_from => :parked, :do => lambda {|object| object.callbacks << :parked}
    @machine.before_transition :except_from => :idling, :do => lambda {|object| object.callbacks << :idling}
    
    @event.fire(@object)
    assert_equal [:idling], @object.callbacks
  end
  
  def test_should_support_to_requirement
    @machine.before_transition :to => :parked, :do => lambda {|object| object.callbacks << :parked}
    @machine.before_transition :to => :idling, :do => lambda {|object| object.callbacks << :idling}
    
    @event.fire(@object)
    assert_equal [:idling], @object.callbacks
  end
  
  def test_should_support_except_to_requirement
    @machine.before_transition :except_to => :parked, :do => lambda {|object| object.callbacks << :parked}
    @machine.before_transition :except_to => :idling, :do => lambda {|object| object.callbacks << :idling}
    
    @event.fire(@object)
    assert_equal [:parked], @object.callbacks
  end
  
  def test_should_support_on_requirement
    @machine.before_transition :on => :park, :do => lambda {|object| object.callbacks << :park}
    @machine.before_transition :on => :ignite, :do => lambda {|object| object.callbacks << :ignite}
    
    @event.fire(@object)
    assert_equal [:ignite], @object.callbacks
  end
  
  def test_should_support_except_on_requirement
    @machine.before_transition :except_on => :park, :do => lambda {|object| object.callbacks << :park}
    @machine.before_transition :except_on => :ignite, :do => lambda {|object| object.callbacks << :ignite}
    
    @event.fire(@object)
    assert_equal [:park], @object.callbacks
  end
  
  def test_should_support_implicit_requirement
    @machine.before_transition :parked => :idling, :do => lambda {|object| object.callbacks << :parked}
    @machine.before_transition :idling => :parked, :do => lambda {|object| object.callbacks << :idling}
    
    @event.fire(@object)
    assert_equal [:parked], @object.callbacks
  end
  
  def test_should_track_states_defined_in_transition_callbacks
    @machine.before_transition :parked => :idling, :do => lambda {}
    @machine.after_transition :first_gear => :second_gear, :do => lambda {}
    
    assert_equal [:parked, :idling, :first_gear, :second_gear], @machine.states.map {|state| state.name}
  end
  
  def test_should_not_duplicate_states_defined_in_multiple_event_transitions
    @machine.before_transition :parked => :idling, :do => lambda {}
    @machine.after_transition :first_gear => :second_gear, :do => lambda {}
    @machine.after_transition :parked => :idling, :do => lambda {}
    
    assert_equal [:parked, :idling, :first_gear, :second_gear], @machine.states.map {|state| state.name}
  end
  
  def test_should_define_predicates_for_each_state
    [:parked?, :idling?].each {|predicate| assert @object.respond_to?(predicate)}
  end
end

class MachineWithOwnerSubclassTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @subclass = Class.new(@klass)
  end
  
  def test_should_have_a_different_collection_of_state_machines
    assert_not_same @klass.state_machines, @subclass.state_machines
  end
  
  def test_should_have_the_same_attribute_associated_state_machines
    assert_equal @klass.state_machines, @subclass.state_machines
  end
end

class MachineWithExistingMachinesOnOwnerClassTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :initial => :parked)
    @second_machine = StateMachine::Machine.new(@klass, :status, :initial => :idling)
    @object = @klass.new
  end
  
  def test_should_track_each_state_machine
    expected = {:state => @machine, :status => @second_machine}
    assert_equal expected, @klass.state_machines
  end
  
  def test_should_initialize_state_for_both_machines
    assert_equal 'parked', @object.state
    assert_equal 'idling', @object.status
  end
end

class MachineWithNamespaceTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :namespace => 'car', :initial => :parked) do
      event :ignite do
        transition :parked => :idling
      end
      
      event :park do
        transition :idling => :parked
      end
    end
    @object = @klass.new
  end
  
  def test_should_namespace_state_predicates
    [:car_parked?, :car_idling?].each do |name|
      assert @object.respond_to?(name)
    end
  end
  
  def test_should_namespace_event_checks
    [:can_ignite_car?, :can_park_car?].each do |name|
      assert @object.respond_to?(name)
    end
  end
  
  def test_should_namespace_event_transition_readers
    [:next_ignite_car_transition, :next_park_car_transition].each do |name|
      assert @object.respond_to?(name)
    end
  end
  
  def test_should_namespace_events
    [:ignite_car, :park_car].each do |name|
      assert @object.respond_to?(name)
    end
  end
  
  def test_should_namespace_bang_events
    [:ignite_car!, :park_car!].each do |name|
      assert @object.respond_to?(name)
    end
  end
end

class MachineFinderWithoutExistingMachineTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.find_or_create(@klass)
  end
  
  def test_should_accept_a_block
    called = false
    StateMachine::Machine.find_or_create(Class.new) do
      called = respond_to?(:event)
    end
    
    assert called
  end
  
  def test_should_create_a_new_machine
    assert_not_nil @machine
  end
  
  def test_should_use_default_state
    assert_equal :state, @machine.attribute
  end
end

class MachineFinderWithExistingOnSameClassTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @existing_machine = StateMachine::Machine.new(@klass)
    @machine = StateMachine::Machine.find_or_create(@klass)
  end
  
  def test_should_accept_a_block
    called = false
    StateMachine::Machine.find_or_create(@klass) do
      called = respond_to?(:event)
    end
    
    assert called
  end
  
  def test_should_not_create_a_new_machine
    assert_same @machine, @existing_machine
  end
end

class MachineFinderWithExistingMachineOnSuperclassTest < Test::Unit::TestCase
  def setup
    integration = Module.new do
      def self.matches?(klass)
        false
      end
    end
    StateMachine::Integrations.const_set('Custom', integration)
    
    @base_class = Class.new
    @base_machine = StateMachine::Machine.new(@base_class, :status, :action => :save, :integration => :custom)
    @base_machine.event(:ignite) {}
    @base_machine.before_transition(lambda {})
    @base_machine.after_transition(lambda {})
    
    @klass = Class.new(@base_class)
    @machine = StateMachine::Machine.find_or_create(@klass, :status)
  end
  
  def test_should_accept_a_block
    called = false
    StateMachine::Machine.find_or_create(Class.new(@base_class)) do
      called = respond_to?(:event)
    end
    
    assert called
  end
  
  def test_should_create_a_new_machine
    assert_not_nil @machine
    assert_not_same @machine, @base_machine
  end
  
  def test_should_copy_the_base_attribute
    assert_equal :status, @machine.attribute
  end
  
  def test_should_copy_the_base_configuration
    assert_equal :save, @machine.action
  end
  
  def test_should_copy_events
    # Can't assert equal arrays since their machines change
    assert_equal 1, @machine.events.length
  end
  
  def test_should_copy_before_callbacks
    assert_equal @base_machine.callbacks[:before], @machine.callbacks[:before]
  end
  
  def test_should_copy_after_transitions
    assert_equal @base_machine.callbacks[:after], @machine.callbacks[:after]
  end
  
  def test_should_use_the_same_integration
    assert (class << @machine; ancestors; end).include?(StateMachine::Integrations::Custom)
  end
  
  def teardown
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineFinderCustomOptionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.find_or_create(@klass, :status, :initial => :parked)
    @object = @klass.new
  end
  
  def test_should_use_custom_attribute
    assert_equal :status, @machine.attribute
  end
  
  def test_should_set_custom_initial_state
    assert_equal :parked, @machine.initial_state(@object).name
  end
end

begin
  # Load library
  require 'rubygems'
  require 'graphviz'
  
  class MachineDrawingTest < Test::Unit::TestCase
    def setup
      @klass = Class.new do
        def self.name; 'Vehicle'; end
      end
      @machine = StateMachine::Machine.new(@klass, :initial => :parked)
      @machine.event :ignite do
        transition :parked => :idling
      end
    end
    
    def test_should_raise_exception_if_invalid_option_specified
      assert_raise(ArgumentError) {@machine.draw(:invalid => true)}
    end
    
    def test_should_save_file_with_class_name_by_default
      graph = @machine.draw(:output => false)
      assert_equal './Vehicle_state.png', graph.instance_variable_get('@filename')
    end
    
    def test_should_allow_base_name_to_be_customized
      graph = @machine.draw(:name => 'machine', :output => false)
      assert_equal './machine.png', graph.instance_variable_get('@filename')
    end
    
    def test_should_allow_format_to_be_customized
      graph = @machine.draw(:format => 'jpg', :output => false)
      assert_equal './Vehicle_state.jpg', graph.instance_variable_get('@filename')
      assert_equal 'jpg', graph.instance_variable_get('@format')
    end
    
    def test_should_allow_path_to_be_customized
      graph = @machine.draw(:path => "#{File.dirname(__FILE__)}/", :output => false)
      assert_equal "#{File.dirname(__FILE__)}/Vehicle_state.png", graph.instance_variable_get('@filename')
    end
    
    def test_should_allow_orientation_to_be_landscape
      graph = @machine.draw(:orientation => 'landscape', :output => false)
      assert_equal 'LR', graph['rankdir']
    end
    
    def test_should_allow_orientation_to_be_portrait
      graph = @machine.draw(:orientation => 'portrait', :output => false)
      assert_equal 'TB', graph['rankdir']
    end
  end
  
  class MachineDrawingWithIntegerStatesTest < Test::Unit::TestCase
    def setup
      @klass = Class.new do
        def self.name; 'Vehicle'; end
      end
      @machine = StateMachine::Machine.new(@klass, :state_id, :initial => :parked)
      @machine.event :ignite do
        transition :parked => :idling
      end
      @machine.state :parked, :value => 1
      @machine.state :idling, :value => 2
      @graph = @machine.draw
    end
    
    def test_should_draw_all_states
      assert_equal 3, @graph.node_count
    end
    
    def test_should_draw_all_events
      assert_equal 2, @graph.edge_count
    end
    
    def test_should_draw_machine
      assert File.exist?('./Vehicle_state_id.png')
    ensure
      FileUtils.rm('./Vehicle_state_id.png')
    end
  end
  
  class MachineDrawingWithNilStatesTest < Test::Unit::TestCase
    def setup
      @klass = Class.new do
        def self.name; 'Vehicle'; end
      end
      @machine = StateMachine::Machine.new(@klass, :initial => :parked)
      @machine.event :ignite do
        transition :parked => :idling
      end
      @machine.state :parked, :value => nil
      @graph = @machine.draw
    end
    
    def test_should_draw_all_states
      assert_equal 3, @graph.node_count
    end
    
    def test_should_draw_all_events
      assert_equal 2, @graph.edge_count
    end
    
    def test_should_draw_machine
      assert File.exist?('./Vehicle_state.png')
    ensure
      FileUtils.rm('./Vehicle_state.png')
    end
  end
  
  class MachineDrawingWithDynamicStatesTest < Test::Unit::TestCase
    def setup
      @klass = Class.new do
        def self.name; 'Vehicle'; end
      end
      @machine = StateMachine::Machine.new(@klass, :initial => :parked)
      @machine.event :activate do
        transition :parked => :idling
      end
      @machine.state :idling, :value => lambda {Time.now}
      @graph = @machine.draw
    end
    
    def test_should_draw_all_states
      assert_equal 3, @graph.node_count
    end
    
    def test_should_draw_all_events
      assert_equal 2, @graph.edge_count
    end
    
    def test_should_draw_machine
      assert File.exist?('./Vehicle_state.png')
    ensure
      FileUtils.rm('./Vehicle_state.png')
    end
  end
  
  class MachineClassDrawingTest < Test::Unit::TestCase
    def setup
      @klass = Class.new do
        def self.name; 'Vehicle'; end
      end
      @machine = StateMachine::Machine.new(@klass)
      @machine.event :ignite do
        transition :parked => :idling
      end
    end
    
    def test_should_raise_exception_if_no_class_names_specified
      exception = assert_raise(ArgumentError) {StateMachine::Machine.draw(nil)}
      assert_equal 'At least one class must be specified', exception.message
    end
    
    def test_should_load_files
      StateMachine::Machine.draw('Switch', :file => "#{File.dirname(__FILE__)}/../classes/switch.rb")
      assert defined?(::Switch)
    ensure
      FileUtils.rm('./Switch_state.png')
    end
    
    def test_should_allow_path_and_format_to_be_customized
      StateMachine::Machine.draw('Switch', :file => "#{File.dirname(__FILE__)}/../classes/switch.rb", :path => "#{File.dirname(__FILE__)}/", :format => 'jpg')
      assert File.exist?("#{File.dirname(__FILE__)}/Switch_state.jpg")
    ensure
      FileUtils.rm("#{File.dirname(__FILE__)}/Switch_state.jpg")
    end
  end
rescue LoadError
  $stderr.puts 'Skipping GraphViz StateMachine::Machine tests. `gem install ruby-graphviz` and try again.'
end
