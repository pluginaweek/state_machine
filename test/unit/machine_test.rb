require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MachineByDefaultTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @object = @klass.new
  end
  
  def test_should_have_an_owner_class
    assert_equal @klass, @machine.owner_class
  end
  
  def test_should_have_an_attribute
    assert_equal 'state', @machine.attribute
  end
  
  def test_should_not_have_an_initial_state
    assert_nil @machine.initial_state(@object)
  end
  
  def test_should_not_have_any_events
    assert @machine.events.empty?
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
  
  def test_should_not_have_any_states
    assert @machine.states.empty?
  end
  
  def test_should_not_be_extended_by_the_active_record_integration
    assert !(class << @machine; ancestors; end).include?(PluginAWeek::StateMachine::Integrations::ActiveRecord)
  end
  
  def test_should_not_be_extended_by_the_datamapper_integration
    assert !(class << @machine; ancestors; end).include?(PluginAWeek::StateMachine::Integrations::DataMapper)
  end
  
  def test_should_define_a_reader_attribute_for_the_attribute
    assert @object.respond_to?(:state)
  end
  
  def test_should_define_a_writer_attribute_for_the_attribute
    assert @object.respond_to?(:state=)
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
    assert (class << @klass; ancestors; end).include?(PluginAWeek::StateMachine::ClassMethods)
  end
  
  def test_should_include_instance_methods_in_owner_class
    assert @klass.included_modules.include?(PluginAWeek::StateMachine::InstanceMethods)
  end
  
  def test_should_define_state_machines_reader
    expected = {'state' => @machine}
    assert_equal expected, @klass.state_machines
  end
end

class MachineWithCustomAttributeTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, 'status')
    @object = @klass.new
  end
  
  def test_should_use_custom_attribute
    assert_equal 'status', @machine.attribute
  end
  
  def test_should_define_a_reader_attribute_for_the_attribute
    assert @object.respond_to?(:status)
  end
  
  def test_should_define_a_writer_attribute_for_the_attribute
    assert @object.respond_to?(:status=)
  end
end

class MachineWithStaticInitialStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'off')
    @object = @klass.new
  end
  
  def test_should_have_an_initial_state
    assert_equal 'off', @machine.initial_state(@object)
  end
  
  def test_should_set_initial_state_on_created_object
    assert_equal 'off', @object.state
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(off), @machine.states
  end
end

class MachineWithDynamicInitialStateTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_accessor :initial_state
    end
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => lambda {|object| object.initial_state || 'default'})
    @object = @klass.new
  end
  
  def test_should_use_the_record_for_determining_the_initial_state
    @object.initial_state = 'off'
    assert_equal 'off', @machine.initial_state(@object)
    
    @object.initial_state = 'on'
    assert_equal 'on', @machine.initial_state(@object)
  end
  
  def test_should_set_initial_state_on_created_object
    assert_equal 'default', @object.state
  end
  
  def test_should_not_be_included_in_known_states
    assert_equal [], @machine.states
  end
end

class MachineWithCustomActionTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new, :action => :save)
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
    PluginAWeek::StateMachine::Integrations.const_set('Custom', integration)
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new, :action => nil, :integration => :custom)
  end
  
  def test_should_have_a_nil_action
    assert_nil @machine.action
  end
  
  def teardown
    PluginAWeek::StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineWithCustomIntegrationTest < Test::Unit::TestCase
  def setup
    PluginAWeek::StateMachine::Integrations.const_set('Custom', Module.new)
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new, :integration => :custom)
  end
  
  def test_should_be_extended_by_the_integration
    assert (class << @machine; ancestors; end).include?(PluginAWeek::StateMachine::Integrations::Custom)
  end
  
  def teardown
    PluginAWeek::StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineTest < Test::Unit::TestCase
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {PluginAWeek::StateMachine::Machine.new(Class.new, :invalid => true)}
  end
end

class MachineWithoutIntegrationTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @object = @klass.new
  end
  
  def test_transaction_should_yield
    @yielded = false
    @machine.within_transaction(@object) do
      @yielded = true
    end
    
    assert @yielded
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
        PluginAWeek::StateMachine::Integrations::Custom.initialized = true
      end
      
      def default_action
        :save
      end
      
      def define_with_scope(name)
        PluginAWeek::StateMachine::Integrations::Custom.with_scopes << name
      end
      
      def define_without_scope(name)
        PluginAWeek::StateMachine::Integrations::Custom.without_scopes << name
      end
    end
    
    PluginAWeek::StateMachine::Integrations.const_set('Custom', @integration)
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new, :integration => :custom)
  end
  
  def test_should_call_after_initialize_hook
    assert @integration.initialized
  end
  
  def test_should_use_the_default_action
    assert_equal :save, @machine.action
  end
  
  def test_should_use_the_custom_action_if_specified
    machine = PluginAWeek::StateMachine::Machine.new(Class.new, :integration => :custom, :action => :save!)
    assert_equal :save!, machine.action
  end
  
  def test_should_define_a_singular_and_plural_with_scope
    assert_equal %w(with_state with_states), @integration.with_scopes
  end
  
  def test_should_define_a_singular_and_plural_without_scope
    assert_equal %w(without_state without_states), @integration.without_scopes
  end
  
  def teardown
    PluginAWeek::StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineAfterBeingCopiedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new, 'state')
    @machine.event(:turn_on) {}
    @machine.before_transition(lambda {})
    @machine.after_transition(lambda {})
    @machine.states # Caches the states variable
    
    @copied_machine = @machine.dup
  end
  
  def test_should_not_have_the_same_collection_of_states
    assert_not_same @copied_machine.states, @machine.states
  end
  
  def test_should_not_have_the_same_collection_of_events
    assert_not_same @copied_machine.events, @machine.events
  end
  
  def test_should_copy_each_event
    assert_not_same @copied_machine.events['turn_on'], @machine.events['turn_on']
  end
  
  def test_should_update_machine_for_each_event
    assert_equal @copied_machine, @copied_machine.events['turn_on'].machine
  end
  
  def test_should_not_update_machine_for_original_event
    assert_equal @machine, @machine.events['turn_on'].machine
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

class MachineAfterChangingContextTest < Test::Unit::TestCase
  def setup
    @original_class = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@original_class, 'state')
    
    @new_class = Class.new(@original_class)
    @new_machine = @machine.within_context(@new_class)
    
    @object = @new_class.new
  end
  
  def test_should_create_copy_of_machine
    assert_not_same @machine, @new_machine
  end
  
  def test_should_update_owner_class
    assert_equal @new_class, @new_machine.owner_class
  end
  
  def test_should_not_change_original_owner_class
    assert_equal @original_class, @machine.owner_class
  end
  
  def test_should_allow_changing_the_initial_state
    new_machine = @machine.within_context(@new_class, :initial => 'off')
    assert_equal 'off', new_machine.initial_state(@object)
  end
  
  def test_should_not_change_original_initial_state_if_updated
    new_machine = @machine.within_context(@new_class, :initial => 'off')
    assert_nil @machine.initial_state(@object)
  end
  
  def test_should_not_update_initial_state_if_not_provided
    assert_nil @new_machine.initial_state(@object)
  end
  
  def test_should_allow_changing_the_integration
    PluginAWeek::StateMachine::Integrations.const_set('Custom', Module.new)
    new_machine = @machine.within_context(@new_class, :integration => :custom)
    assert (class << new_machine; ancestors; end).include?(PluginAWeek::StateMachine::Integrations::Custom)
  end
  
  def test_should_not_change_original_integration_if_updated
    PluginAWeek::StateMachine::Integrations.const_set('Custom', Module.new)
    new_machine = @machine.within_context(@new_class, :integration => :custom)
    assert !(class << @machine; ancestors; end).include?(PluginAWeek::StateMachine::Integrations::Custom)
  end
  
  def test_should_change_the_associated_machine_in_the_new_class
    assert_equal @new_machine, @new_class.state_machines['state']
  end
  
  def test_should_not_change_the_associated_machine_in_the_original_class
    assert_equal @machine, @original_class.state_machines['state']
  end
  
  def test_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {@machine.within_context(@new_class, :invalid => true)}
  end
  
  def teardown
    PluginAWeek::StateMachine::Integrations.send(:remove_const, 'Custom') if PluginAWeek::StateMachine::Integrations.const_defined?('Custom')
  end
end

class MachineWithConflictingAttributeAccessorsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_accessor :status
      
      def state
        status
      end
      
      def state=(value)
        self.status = value
      end
    end
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @object = @klass.new
  end
  
  def test_should_not_define_attribute_reader
    @object.status = 'on'
    assert_equal 'on', @object.state
  end
  
  def test_should_not_define_attribute_writer
    @object.state = 'on'
    assert_equal 'on', @object.status
  end
end

class MachineWithConflictingScopesTest < Test::Unit::TestCase
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
    end
    
    integration = Module.new do
      def define_with_scope(name)
        raise ArgumentError, 'should not define a with scope'
      end
      
      def define_without_scope(name)
        raise ArgumentError, 'should not define a without scope'
      end
    end
    PluginAWeek::StateMachine::Integrations.const_set('Custom', integration)
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :integration => :custom)
  end
  
  def test_should_not_define_singular_with_scope
    assert_equal :with_state, @klass.with_state
  end
  
  def test_should_not_define_plural_with_scope
    assert_equal :with_states, @klass.with_states
  end
  
  def test_should_not_define_singular_without_scope
    assert_equal :without_state, @klass.without_state
  end
  
  def test_should_not_define_plural_without_scope
    assert_equal :without_states, @klass.without_states
  end
  
  def teardown
    PluginAWeek::StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineWithEventsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new)
  end
  
  def test_should_create_event_with_given_name
    event = @machine.event(:turn_on) {}
    assert_equal 'turn_on', event.name
  end
  
  def test_should_evaluate_block_within_event_context
    responded = false
    @machine.event :turn_on do
      responded = respond_to?(:transition)
    end
    
    assert responded
  end
  
  def test_should_have_events
    @machine.event(:turn_on) {}
    assert_equal %w(turn_on), @machine.events.keys
  end
end

class MachineWithConflictingPredefinedInitializeTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :initialized
      attr_reader :block_given
      
      def initialize
        @initialized = true
        @block_given = block_given?
      end
    end
    
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'off')
    @object = @klass.new {}
  end
  
  def test_should_not_override_existing_method
    assert @object.initialized
  end
  
  def test_should_still_initialize_state
    assert_equal 'off', @object.state
  end
  
  def test_should_preserve_block
    assert @object.block_given
  end
end

class MachineWithConflictingPostdefinedInitializeTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'off')
    @klass.class_eval do
      attr_reader :initialized
      attr_reader :block_given
      
      def initialize
        @initialized = true
        @block_given = block_given?
      end
    end
    
    @object = @klass.new {}
  end
  
  def test_should_not_override_existing_method
    assert @object.initialized
  end
  
  def test_should_still_initialize_state
    assert_equal 'off', @object.state
  end
  
  def test_should_preserve_block
    assert @object.block_given
  end
end

class MachineWithConflictingSuperclassInitializeTest < Test::Unit::TestCase
  def setup
    @superclass = Class.new do
      attr_reader :initialized
      attr_reader :block_given
      
      def initialize
        @initialized = true
        @block_given = block_given?
      end
    end
    @klass = Class.new(@superclass)
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'off')
    @object = @klass.new {}
  end
  
  def test_should_not_override_existing_method
    assert @object.initialized
  end
  
  def test_should_still_initialize_state
    assert_equal 'off', @object.state
  end
  
  def test_should_preserve_block
    assert @object.block_given
  end
end

class MachineWithConflictingPredefinedAndSuperclassInitializeTest < Test::Unit::TestCase
  def setup
    @superclass = Class.new do
      attr_reader :base_initialized
      
      def initialize
        @base_initialized = true
      end
    end
    @klass = Class.new(@superclass) do
      attr_reader :initialized
      
      def initialize
        super
        @initialized = true
      end
    end
    
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'off')
    @object = @klass.new
  end
  
  def test_should_not_override_base_method
    assert @object.base_initialized
  end
  
  def test_should_not_override_existing_method
    assert @object.initialized
  end
  
  def test_should_still_initialize_state
    assert_equal 'off', @object.state
  end
end

class MachineWithConflictingPostdefinedAndSuperclassInitializeTest < Test::Unit::TestCase
  def setup
    @superclass = Class.new do
      attr_reader :base_initialized
      
      def initialize
        @base_initialized = true
      end
    end
    @klass = Class.new(@superclass)    
    
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'off')
    @klass.class_eval do
      attr_reader :initialized
      
      def initialize
        super
        @initialized = true
      end
    end
    
    @object = @klass.new
  end
  
  def test_should_not_override_base_method
    assert @object.base_initialized
  end
  
  def test_should_not_override_existing_method
    assert @object.initialized
  end
  
  def test_should_still_initialize_state
    assert_equal 'off', @object.state
  end
end

class MachineWithConflictingMethodAddedTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self
        attr_reader :called_method_added
        
        def method_added(method)
          super
          @called_method_added = true
        end
      end
    end
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'off')
    @object = @klass.new
  end
  
  def test_should_not_override_existing_method
    assert @klass.called_method_added
  end
  
  def test_should_still_initialize_state
    assert_equal 'off', @object.state
  end
end

class MachineWithExistingAttributeValue < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def initialize
        @state = 'on'
      end
    end
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'off')
    @object = @klass.new
  end
  
  def test_should_not_set_the_initial_state
    assert_equal 'on', @object.state
  end
end

class MachineWithExistingEventTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new)
    @event = @machine.event(:turn_on) {}
    @same_event = @machine.event(:turn_on) {}
  end
  
  def test_should_not_create_new_event
    assert_same @event, @same_event
  end
end

class MachineWithEventsWithTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Class.new)
    @machine.event(:turn_on) do
      transition :to => 'on', :from => 'off'
      transition :to => 'error', :from => 'unknown'
    end
  end
  
  def test_should_have_events
    assert_equal %w(turn_on), @machine.events.keys
  end
  
  def test_should_track_states_defined_in_event_transitions
    assert_equal %w(error off on unknown), @machine.states.sort
  end
  
  def test_should_not_duplicate_states_defined_in_multiple_event_transitions
    @machine.event :turn_off do
      transition :to => 'off', :from => 'on'
    end
    
    assert_equal %w(error off on unknown), @machine.states.sort
  end
end

class MachineWithTransitionCallbacksTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_accessor :callbacks
    end
    
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @event = @machine.event :turn_on do
      transition :to => 'on', :from => 'off'
    end
    
    @object = @klass.new
    @object.state = 'off'
    @object.callbacks = []
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {@machine.before_transition :invalid => true}
  end
  
  def test_should_raise_exception_if_do_option_not_specified
    assert_raise(ArgumentError) {@machine.before_transition :to => 'on'}
  end
  
  def test_should_invoke_callbacks_during_transition
    @machine.before_transition lambda {|object| object.callbacks << 'before'}
    @machine.after_transition lambda {|object| object.callbacks << 'after'}
    
    @event.fire(@object)
    assert_equal %w(before after), @object.callbacks
  end
  
  def test_should_support_from_requirement
    @machine.before_transition :from => 'off', :do => lambda {|object| object.callbacks << 'off'}
    @machine.before_transition :from => 'on', :do => lambda {|object| object.callbacks << 'on'}
    
    @event.fire(@object)
    assert_equal %w(off), @object.callbacks
  end
  
  def test_should_support_except_from_requirement
    @machine.before_transition :except_from => 'off', :do => lambda {|object| object.callbacks << 'off'}
    @machine.before_transition :except_from => 'on', :do => lambda {|object| object.callbacks << 'on'}
    
    @event.fire(@object)
    assert_equal %w(on), @object.callbacks
  end
  
  def test_should_support_to_requirement
    @machine.before_transition :to => 'off', :do => lambda {|object| object.callbacks << 'off'}
    @machine.before_transition :to => 'on', :do => lambda {|object| object.callbacks << 'on'}
    
    @event.fire(@object)
    assert_equal %w(on), @object.callbacks
  end
  
  def test_should_support_except_to_requirement
    @machine.before_transition :except_to => 'off', :do => lambda {|object| object.callbacks << 'off'}
    @machine.before_transition :except_to => 'on', :do => lambda {|object| object.callbacks << 'on'}
    
    @event.fire(@object)
    assert_equal %w(off), @object.callbacks
  end
  
  def test_should_support_on_requirement
    @machine.before_transition :on => 'turn_off', :do => lambda {|object| object.callbacks << 'turn_off'}
    @machine.before_transition :on => 'turn_on', :do => lambda {|object| object.callbacks << 'turn_on'}
    
    @event.fire(@object)
    assert_equal %w(turn_on), @object.callbacks
  end
  
  def test_should_support_except_on_requirement
    @machine.before_transition :except_on => 'turn_off', :do => lambda {|object| object.callbacks << 'turn_off'}
    @machine.before_transition :except_on => 'turn_on', :do => lambda {|object| object.callbacks << 'turn_on'}
    
    @event.fire(@object)
    assert_equal %w(turn_off), @object.callbacks
  end
  
  def test_should_track_states_defined_in_transition_callbacks
    @machine.before_transition :from => 'off', :to => 'on', :do => lambda {}
    @machine.after_transition :from => 'unknown', :to => 'error', :do => lambda {}
    
    assert_equal %w(error off on unknown), @machine.states.sort
  end
  
  def test_should_not_duplicate_states_defined_in_multiple_event_transitions
    @machine.before_transition :from => 'off', :to => 'on', :do => lambda {}
    @machine.after_transition :from => 'unknown', :to => 'error', :do => lambda {}
    @machine.after_transition :from => 'off', :to => 'on', :do => lambda {}
    
    assert_equal %w(error off on unknown), @machine.states.sort
  end
end

class MachineWithOtherStates < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'on')
    @machine.other_states('on', 'off')
  end
  
  def test_should_include_other_states_in_known_states
    assert_equal %w(off on), @machine.states.sort
  end
end

class MachineWithOwnerSubclassTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.new(@klass)
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
    @machine = PluginAWeek::StateMachine::Machine.new(@klass, :initial => 'off')
    @second_machine = PluginAWeek::StateMachine::Machine.new(@klass, 'status', :initial => 'active')
    @object = @klass.new
  end
  
  def test_should_track_each_state_machine
    expected = {'state' => @machine, 'status' => @second_machine}
    assert_equal expected, @klass.state_machines
  end
  
  def test_should_initialize_state_for_both_machines
    assert_equal 'off', @object.state
    assert_equal 'active', @object.status
  end
end

class MachineFinderWithoutExistingMachineTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.find_or_create(@klass)
  end
  
  def test_should_create_a_new_machine
    assert_not_nil @machine
  end
  
  def test_should_use_default_state
    assert_equal 'state', @machine.attribute
  end
end

class MachineFinderWithExistingOnSameClassTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @existing_machine = PluginAWeek::StateMachine::Machine.new(@klass)
    @machine = PluginAWeek::StateMachine::Machine.find_or_create(@klass)
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
    PluginAWeek::StateMachine::Integrations.const_set('Custom', integration)
    
    @base_class = Class.new
    @base_machine = PluginAWeek::StateMachine::Machine.new(@base_class, 'status', :action => :save, :integration => :custom)
    @base_machine.event(:turn_on) {}
    @base_machine.before_transition(lambda {})
    @base_machine.after_transition(lambda {})
    
    @klass = Class.new(@base_class)
    @machine = PluginAWeek::StateMachine::Machine.find_or_create(@klass, 'status')
  end
  
  def test_should_create_a_new_machine
    assert_not_nil @machine
    assert_not_same @machine, @base_machine
  end
  
  def test_should_copy_the_base_attribute
    assert_equal 'status', @machine.attribute
  end
  
  def test_should_copy_the_base_configuration
    assert_equal :save, @machine.action
  end
  
  def test_should_copy_events
    # Can't assert equal arrays since their machines change
    assert_equal 1, @machine.events.size
  end
  
  def test_should_copy_before_callbacks
    assert_equal @base_machine.callbacks[:before], @machine.callbacks[:before]
  end
  
  def test_should_copy_after_transitions
    assert_equal @base_machine.callbacks[:after], @machine.callbacks[:after]
  end
  
  def test_should_use_the_same_integration
    assert (class << @machine; ancestors; end).include?(PluginAWeek::StateMachine::Integrations::Custom)
  end
  
  def teardown
    PluginAWeek::StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class MachineFinderCustomOptionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = PluginAWeek::StateMachine::Machine.find_or_create(@klass, 'status', :initial => 'off')
    @object = @klass.new
  end
  
  def test_should_use_custom_attribute
    assert_equal 'status', @machine.attribute
  end
  
  def test_should_set_custom_initial_state
    assert_equal 'off', @machine.initial_state(@object)
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
      @machine = PluginAWeek::StateMachine::Machine.new(@klass)
      @machine.event :ignite do
        transition :from => 'parked', :to => 'idling'
      end
    end
    
    def test_should_raise_exception_if_invalid_option_specified
      assert_raise(ArgumentError) {@machine.draw(:invalid => true)}
    end
    
    def test_should_save_file_with_class_name_by_default
      @machine.draw
      assert File.exist?('./Vehicle_state.png')
    ensure
      FileUtils.rm('./Vehicle_state.png')
    end
    
    def test_should_allow_base_name_to_be_customized
      @machine.draw(:name => 'machine')
      assert File.exist?('./machine.png')
    ensure
      FileUtils.rm('./machine.png')
    end
    
    def test_should_allow_format_to_be_customized
      @machine.draw(:format => 'jpg')
      assert File.exist?('./Vehicle_state.jpg')
    ensure
      FileUtils.rm('./Vehicle_state.jpg')
    end
    
    def test_should_allow_path_to_be_customized
      @machine.draw(:path => "#{File.dirname(__FILE__)}/")
      assert File.exist?("#{File.dirname(__FILE__)}/Vehicle_state.png")
    ensure
      FileUtils.rm("#{File.dirname(__FILE__)}/Vehicle_state.png")
    end
  end
  
  class MachineClassDrawingTest < Test::Unit::TestCase
    def setup
      @klass = Class.new do
        def self.name; 'Vehicle'; end
      end
      @machine = PluginAWeek::StateMachine::Machine.new(@klass)
      @machine.event :ignite do
        transition :from => 'parked', :to => 'idling'
      end
    end
    
    def test_should_raise_exception_if_no_class_names_specified
      assert_raise(ArgumentError) {PluginAWeek::StateMachine::Machine.draw(nil)}
    end
    
    def test_should_load_files
      PluginAWeek::StateMachine::Machine.draw('Switch', :file => "#{File.dirname(__FILE__)}/../classes/switch.rb")
      assert defined?(::Switch)
    ensure
      FileUtils.rm('./Switch_state.png')
    end
    
    def test_should_allow_path_and_format_to_be_customized
      PluginAWeek::StateMachine::Machine.draw('Switch', :file => "#{File.dirname(__FILE__)}/../classes/switch.rb", :path => "#{File.dirname(__FILE__)}/", :format => 'jpg')
      assert File.exist?("#{File.dirname(__FILE__)}/Switch_state.jpg")
    ensure
      FileUtils.rm("#{File.dirname(__FILE__)}/Switch_state.jpg")
    end
  end
rescue LoadError
  $stderr.puts 'Skipping GraphViz tests. `gem install ruby-graphviz` and try again.'
end
