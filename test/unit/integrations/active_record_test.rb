require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

begin
  # Load library
  require 'rubygems'
  
  gem 'activerecord', ENV['AR_VERSION'] ? "=#{ENV['AR_VERSION']}" : '>=2.0.0'
  require 'active_record'
  
  FIXTURES_ROOT = File.dirname(__FILE__) + '/../../fixtures/'
  
  # Load TestCase helpers
  require 'active_support/test_case'
  require 'active_record/fixtures'
  
  require 'active_record/version'
  if ActiveRecord::VERSION::STRING >= '2.1.0'
    require 'active_record/test_case'
  else
    class ActiveRecord::TestCase < ActiveSupport::TestCase
      self.fixture_path = FIXTURES_ROOT
      self.use_instantiated_fixtures = false
      self.use_transactional_fixtures = true
    end
  end
  
  # Establish database connection
  ActiveRecord::Base.establish_connection({'adapter' => 'sqlite3', 'database' => ':memory:'})
  ActiveRecord::Base.logger = Logger.new("#{File.dirname(__FILE__)}/../../active_record.log")
  
  # Add model/observer creation helpers
  ActiveRecord::TestCase.class_eval do
    # Creates a new ActiveRecord model (and the associated table)
    def new_model(create_table = true, &block)
      model = Class.new(ActiveRecord::Base) do
        connection.create_table(:foo, :force => true) {|t| t.string(:state)} if create_table
        set_table_name('foo')
        
        def self.name; 'ActiveRecordTest::Foo'; end
      end
      model.class_eval(&block) if block_given?
      model
    end
    
    # Creates a new ActiveRecord observer
    def new_observer(model, &block)
      observer = Class.new(ActiveRecord::Observer) do
        attr_accessor :notifications
        
        def initialize
          super
          @notifications = []
        end
      end
      observer.observe(model)
      observer.class_eval(&block) if block_given?
      observer
    end
  end
  
  module ActiveRecordTest
    class IntegrationTest < ActiveRecord::TestCase
      def test_should_match_if_class_inherits_from_active_record
        assert StateMachine::Integrations::ActiveRecord.matches?(new_model)
      end
      
      def test_should_not_match_if_class_does_not_inherit_from_active_record
        assert !StateMachine::Integrations::ActiveRecord.matches?(Class.new)
      end
    end
    
    class MachineByDefaultTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
      end
      
      def test_should_use_save_as_action
        assert_equal :save, @machine.action
      end
      
      def test_should_use_transactions
        assert_equal true, @machine.use_transactions
      end
      
      def test_should_create_notifier_before_callback
        assert_equal 1, @machine.callbacks[:before].size
      end
      
      def test_should_create_notifier_after_callback
        assert_equal 1, @machine.callbacks[:after].size
      end
    end
    
    class MachineTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
        @machine.state :parked, :first_gear
        @machine.state :idling, :value => lambda {'idling'}
      end
      
      def test_should_rollback_transaction_if_false
        @machine.within_transaction(@model.new) do
          @model.create
          false
        end
        
        assert_equal 0, @model.count
      end
      
      def test_should_not_rollback_transaction_if_true
        @machine.within_transaction(@model.new) do
          @model.create
          true
        end
        
        assert_equal 1, @model.count
      end
      
      def test_should_invalidate_using_errors
        I18n.backend = I18n::Backend::Simple.new if Object.const_defined?(:I18n)
        
        record = @model.new
        record.state = 'parked'
        
        @machine.invalidate(record, :state, :invalid_transition, [[:event, :park]])
        
        assert_equal ['State cannot transition via "park"'], record.errors.full_messages
      end
      
      def test_should_auto_prefix_custom_attributes_on_invalidation
        record = @model.new
        @machine.invalidate(record, :event, :invalid)
        
        assert_equal ['State event is invalid'], record.errors.full_messages
      end
      
      def test_should_clear_errors_on_reset
        record = @model.new
        record.state = 'parked'
        record.errors.add(:state, 'is invalid')
        
        @machine.reset(record)
        assert_equal [], record.errors.full_messages
      end
      
      def test_should_not_override_the_column_reader
        record = @model.new
        record[:state] = 'parked'
        assert_equal 'parked', record.state
      end
      
      def test_should_not_override_the_column_writer
        record = @model.new
        record.state = 'parked'
        assert_equal 'parked', record[:state]
      end
    end
    
    class MachineWithoutDatabaseTest < ActiveRecord::TestCase
      def setup
        @model = new_model(false) do
          # Simulate the database not being available entirely
          def self.connection
            raise ActiveRecord::ConnectionNotEstablished
          end
        end
      end
      
      def test_should_allow_machine_creation
        assert_nothing_raised { StateMachine::Machine.new(@model) }
      end
    end
    
    class MachineUnmigratedTest < ActiveRecord::TestCase
      def setup
        @model = new_model(false)
        
        # Drop the table so that it definitely doesn't exist
        @model.connection.drop_table(:foo) if @model.table_exists?
      end
      
      def test_should_allow_machine_creation
        assert_nothing_raised { StateMachine::Machine.new(@model) }
      end
    end
    
    class MachineWithStaticInitialStateTest < ActiveRecord::TestCase
      def setup
        @model = new_model do
          attr_accessor :value
        end
        @machine = StateMachine::Machine.new(@model, :initial => :parked)
      end
      
      def test_should_set_initial_state_on_created_object
        record = @model.new
        assert_equal 'parked', record.state
      end
      
      def test_should_set_initial_state_with_nil_attributes
        record = @model.new(nil)
        assert_equal 'parked', record.state
      end
      
      def test_should_still_set_attributes
        record = @model.new(:value => 1)
        assert_equal 1, record.value
      end
      
      def test_should_still_allow_initialize_blocks
        block_args = nil
        record = @model.new do |*args|
          block_args = args
        end
        
        assert_equal [record], block_args
      end
      
      def test_should_set_attributes_prior_to_after_initialize_hook
        state = nil
        @model.class_eval do
          define_method(:after_initialize) do
            state = self.state
          end
        end
        @model.new
        assert_equal 'parked', state
      end
      
      def test_should_set_initial_state_before_setting_attributes
        @model.class_eval do
          attr_accessor :state_during_setter
          
          define_method(:value=) do |value|
            self.state_during_setter = state
          end
        end
        
        record = @model.new(:value => 1)
        assert_equal 'parked', record.state_during_setter
      end
      
      def test_should_not_set_initial_state_after_already_initialized
        record = @model.new(:value => 1)
        assert_equal 'parked', record.state
        
        record.state = 'idling'
        record.attributes = {}
        assert_equal 'idling', record.state
      end
    end
    
    class MachineWithDynamicInitialStateTest < ActiveRecord::TestCase
      def setup
        @model = new_model do
          attr_accessor :value
        end
        @machine = StateMachine::Machine.new(@model, :initial => lambda {|object| :parked})
        @machine.state :parked
      end
      
      def test_should_set_initial_state_on_created_object
        record = @model.new
        assert_equal 'parked', record.state
      end
      
      def test_should_still_set_attributes
        record = @model.new(:value => 1)
        assert_equal 1, record.value
      end
      
      def test_should_still_allow_initialize_blocks
        block_args = nil
        record = @model.new do |*args|
          block_args = args
        end
        
        assert_equal [record], block_args
      end
      
      def test_should_set_attributes_prior_to_after_initialize_hook
        state = nil
        @model.class_eval do
          define_method(:after_initialize) do
            state = self.state
          end
        end
        @model.new
        assert_equal 'parked', state
      end
      
      def test_should_set_initial_state_after_setting_attributes
        @model.class_eval do
          attr_accessor :state_during_setter
          
          define_method(:value=) do |value|
            self.state_during_setter = state || 'nil'
          end
        end
        
        record = @model.new(:value => 1)
        assert_equal 'nil', record.state_during_setter
      end
      
      def test_should_not_set_initial_state_after_already_initialized
        record = @model.new(:value => 1)
        assert_equal 'parked', record.state
        
        record.state = 'idling'
        record.attributes = {}
        assert_equal 'idling', record.state
      end
    end
    
    class MachineWithColumnDefaultTest < ActiveRecord::TestCase
      def setup
        @model = new_model do
          connection.add_column :foo, :status, :string, :default => 'idling'
        end
        @machine = StateMachine::Machine.new(@model, :status, :initial => :parked)
        @record = @model.new
      end
      
      def test_should_use_machine_default
        assert_equal 'parked', @record.status
      end
    end
    
    class MachineWithConflictingPredicateTest < ActiveRecord::TestCase
      def setup
        @model = new_model do
          def state?(*args)
            true
          end
        end
        
        @machine = StateMachine::Machine.new(@model)
        @record = @model.new
      end
      
      def test_should_not_define_attribute_predicate
        assert @record.state?
      end
    end
    
    class MachineWithColumnStateAttributeTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model, :initial => :parked)
        @machine.other_states(:idling)
        
        @record = @model.new
      end
      
      def test_should_have_an_attribute_predicate
        assert @record.respond_to?(:state?)
      end
      
      def test_should_test_for_existence_on_predicate_without_parameters
        assert @record.state?
        
        @record.state = nil
        assert !@record.state?
      end
      
      def test_should_return_false_for_predicate_if_does_not_match_current_value
        assert !@record.state?(:idling)
      end
      
      def test_should_return_true_for_predicate_if_matches_current_value
        assert @record.state?(:parked)
      end
      
      def test_should_raise_exception_for_predicate_if_invalid_state_specified
        assert_raise(IndexError) { @record.state?(:invalid) }
      end
    end
    
    class MachineWithNonColumnStateAttributeUndefinedTest < ActiveRecord::TestCase
      def setup
        @model = new_model do
          def initialize
            # Skip attribute initialization
            @initialized_state_machines = true
            super
          end
        end
        
        @machine = StateMachine::Machine.new(@model, :status, :initial => :parked)
        @machine.other_states(:idling)
        @record = @model.new
      end
      
      def test_should_not_define_a_reader_attribute_for_the_attribute
        assert !@record.respond_to?(:status)
      end
      
      def test_should_not_define_a_writer_attribute_for_the_attribute
        assert !@record.respond_to?(:status=)
      end
      
      def test_should_define_an_attribute_predicate
        assert @record.respond_to?(:status?)
      end
      
      def test_should_raise_exception_on_predicate_without_parameters
        old_verbose, $VERBOSE = $VERBOSE, nil
        assert_raise(NoMethodError) { @record.status? }
      ensure
        $VERBOSE = old_verbose
      end
    end
    
    class MachineWithNonColumnStateAttributeDefinedTest < ActiveRecord::TestCase
      def setup
        @model = new_model do
          attr_accessor :status
        end
        
        @machine = StateMachine::Machine.new(@model, :status, :initial => :parked)
        @machine.other_states(:idling)
        @record = @model.new
      end
      
      def test_should_return_false_for_predicate_if_does_not_match_current_value
        assert !@record.status?(:idling)
      end
      
      def test_should_return_true_for_predicate_if_matches_current_value
        assert @record.status?(:parked)
      end
      
      def test_should_raise_exception_for_predicate_if_invalid_state_specified
        assert_raise(IndexError) { @record.status?(:invalid) }
      end
      
      def test_should_set_initial_state_on_created_object
        assert_equal 'parked', @record.status
      end
    end
    
    class MachineWithCustomAttributeTest < ActiveRecord::TestCase
      def setup
        @model = new_model do
          alias_attribute :vehicle_status, :state
        end
        
        @machine = StateMachine::Machine.new(@model, :status, :attribute => :vehicle_status)
        @machine.state :parked
        
        @record = @model.new
      end
      
      def test_should_add_validation_errors_to_custom_attribute
        @record.vehicle_status = 'invalid'
        
        assert !@record.valid?
        assert_equal ['Vehicle status is invalid'], @record.errors.full_messages
        
        @record.vehicle_status = 'parked'
        assert @record.valid?
      end
      
      def test_should_check_custom_attribute_for_predicate
        @record.vehicle_status = nil
        assert !@record.status?(:parked)
        
        @record.vehicle_status = 'parked'
        assert @record.status?(:parked)
      end
    end
    
    class MachineWithInitializedStateTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model, :initial => :parked)
        @machine.state nil, :idling
      end
      
      def test_should_allow_nil_initial_state_when_static
        record = @model.new(:state => nil)
        assert_nil record.state
      end
      
      def test_should_allow_nil_initial_state_when_dynamic
        @machine.initial_state = lambda {:parked}
        record = @model.new(:state => nil)
        assert_nil record.state
      end
      
      def test_should_allow_different_initial_state_when_static
        record = @model.new(:state => 'idling')
        assert_equal 'idling', record.state
      end
      
      def test_should_allow_different_initial_state_when_dynamic
        @machine.initial_state = lambda {:parked}
        record = @model.new(:state => 'idling')
        assert_equal 'idling', record.state
      end
      
      def test_should_use_default_state_if_protected
        @model.class_eval do
          attr_protected :state
        end
        
        record = @model.new(:state => 'idling')
        assert_equal 'parked', record.state
      end
    end
    
    class MachineWithCallbacksTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model, :initial => :parked)
        @machine.other_states :idling
        @machine.event :ignite
        
        @record = @model.new(:state => 'parked')
        @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
      end
      
      def test_should_run_before_callbacks
        called = false
        @machine.before_transition(lambda {called = true})
        
        @transition.perform
        assert called
      end
      
      def test_should_pass_record_to_before_callbacks_with_one_argument
        record = nil
        @machine.before_transition(lambda {|arg| record = arg})
        
        @transition.perform
        assert_equal @record, record
      end
      
      def test_should_pass_record_and_transition_to_before_callbacks_with_multiple_arguments
        callback_args = nil
        @machine.before_transition(lambda {|*args| callback_args = args})
        
        @transition.perform
        assert_equal [@record, @transition], callback_args
      end
      
      def test_should_run_before_callbacks_outside_the_context_of_the_record
        context = nil
        @machine.before_transition(lambda {context = self})
        
        @transition.perform
        assert_equal self, context
      end
      
      def test_should_run_after_callbacks
        called = false
        @machine.after_transition(lambda {called = true})
        
        @transition.perform
        assert called
      end
      
      def test_should_pass_record_to_after_callbacks_with_one_argument
        record = nil
        @machine.after_transition(lambda {|arg| record = arg})
        
        @transition.perform
        assert_equal @record, record
      end
      
      def test_should_pass_record_and_transition_to_after_callbacks_with_multiple_arguments
        callback_args = nil
        @machine.after_transition(lambda {|*args| callback_args = args})
        
        @transition.perform
        assert_equal [@record, @transition], callback_args
      end
      
      def test_should_run_after_callbacks_outside_the_context_of_the_record
        context = nil
        @machine.after_transition(lambda {context = self})
        
        @transition.perform
        assert_equal self, context
      end
      
      def test_should_include_transition_states_in_known_states
        @machine.before_transition :to => :first_gear, :do => lambda {}
        
        assert_equal [:parked, :idling, :first_gear], @machine.states.map {|state| state.name}
      end
      
      def test_should_allow_symbolic_callbacks
        callback_args = nil
        
        klass = class << @record; self; end
        klass.send(:define_method, :after_ignite) do |*args|
          callback_args = args
        end
        
        @machine.before_transition(:after_ignite)
        
        @transition.perform
        assert_equal [@transition], callback_args
      end
      
      def test_should_allow_string_callbacks
        class << @record
          attr_reader :callback_result
        end
        
        @machine.before_transition('@callback_result = [1, 2, 3]')
        @transition.perform
        
        assert_equal [1, 2, 3], @record.callback_result
      end
    end
    
    class MachineWithFailedBeforeCallbacksTest < ActiveRecord::TestCase
      def setup
        @before_count = 0
        @after_count = 0
        
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
        @machine.state :parked, :idling
        @machine.event :ignite
        @machine.before_transition(lambda {@before_count += 1; false})
        @machine.before_transition(lambda {@before_count += 1})
        @machine.after_transition(lambda {@after_count += 1})
        
        @record = @model.new(:state => 'parked')
        @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
        @result = @transition.perform
      end
      
      def test_should_not_be_successful
        assert !@result
      end
      
      def test_should_not_change_current_state
        assert_equal 'parked', @record.state
      end
      
      def test_should_not_run_action
        assert @record.new_record?
      end
      
      def test_should_not_run_further_before_callbacks
        assert_equal 1, @before_count
      end
      
      def test_should_not_run_after_callbacks
        assert_equal 0, @after_count
      end
    end
    
    class MachineWithFailedActionTest < ActiveRecord::TestCase
      def setup
        @model = new_model do
          validates_inclusion_of :state, :in => %w(first_gear)
        end
        
        @machine = StateMachine::Machine.new(@model)
        @machine.state :parked, :idling
        @machine.event :ignite
        
        @before_transition_called = false
        @after_transition_called = false
        @after_transition_with_failures_called = false
        @machine.before_transition(lambda {@before_transition_called = true})
        @machine.after_transition(lambda {@after_transition_called = true})
        @machine.after_transition(lambda {@after_transition_with_failures_called = true}, :include_failures => true)
        
        @record = @model.new(:state => 'parked')
        @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
        @result = @transition.perform
      end
      
      def test_should_not_be_successful
        assert !@result
      end
      
      def test_should_not_change_current_state
        assert_equal 'parked', @record.state
      end
      
      def test_should_not_save_record
        assert @record.new_record?
      end
      
      def test_should_run_before_callback
        assert @before_transition_called
      end
      
      def test_should_not_run_after_callback_if_not_including_failures
        assert !@after_transition_called
      end
      
      def test_should_run_after_callback_if_including_failures
        assert @after_transition_with_failures_called
      end
    end
    
    class MachineWithValidationsTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
        @machine.state :parked
        
        @record = @model.new
      end
      
      def test_should_be_valid_if_state_is_known
        @record.state = 'parked'
        
        assert @record.valid?
      end
      
      def test_should_not_be_valid_if_state_is_unknown
        @record.state = 'invalid'
        
        assert !@record.valid?
        assert_equal ['State is invalid'], @record.errors.full_messages
      end
    end
    
    class MachineWithStateDrivenValidationsTest < ActiveRecord::TestCase
      def setup
        @model = new_model do
          attr_accessor :seatbelt
        end
        
        @machine = StateMachine::Machine.new(@model)
        @machine.state :first_gear, :second_gear do
          validates_presence_of :seatbelt
        end
        @machine.other_states :parked
      end
      
      def test_should_be_valid_if_validation_fails_outside_state_scope
        record = @model.new(:state => 'parked', :seatbelt => nil)
        assert record.valid?
      end
      
      def test_should_be_invalid_if_validation_fails_within_state_scope
        record = @model.new(:state => 'first_gear', :seatbelt => nil)
        assert !record.valid?
      end
      
      def test_should_be_valid_if_validation_succeeds_within_state_scope
        record = @model.new(:state => 'second_gear', :seatbelt => true)
        assert record.valid?
      end
    end
    
    class MachineWithFailedAfterCallbacksTest < ActiveRecord::TestCase
       def setup
        @after_count = 0
        
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
        @machine.state :parked, :idling
        @machine.event :ignite
        @machine.after_transition(lambda {@after_count += 1; false})
        @machine.after_transition(lambda {@after_count += 1})
        
        @record = @model.new(:state => 'parked')
        @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
        @result = @transition.perform
      end
      
      def test_should_be_successful
        assert @result
      end
      
      def test_should_change_current_state
        assert_equal 'idling', @record.state
      end
      
      def test_should_save_record
        assert !@record.new_record?
      end
      
      def test_should_not_run_further_after_callbacks
        assert_equal 1, @after_count
      end
    end
    
    class MachineWithEventAttributesOnValidationTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
        @machine.event :ignite do
          transition :parked => :idling
        end
        
        @record = @model.new
        @record.state = 'parked'
        @record.state_event = 'ignite'
      end
      
      def test_should_fail_if_event_is_invalid
        @record.state_event = 'invalid'
        assert !@record.valid?
        assert_equal ['State event is invalid'], @record.errors.full_messages
      end
      
      def test_should_fail_if_event_has_no_transition
        @record.state = 'idling'
        assert !@record.valid?
        assert_equal ['State event cannot transition when idling'], @record.errors.full_messages
      end
      
      def test_should_be_successful_if_event_has_transition
        assert @record.valid?
      end
      
      def test_should_run_before_callbacks
        ran_callback = false
        @machine.before_transition { ran_callback = true }
        
        @record.valid?
        assert ran_callback
      end
      
      def test_should_persist_new_state
        @record.valid?
        assert_equal 'idling', @record.state
      end
      
      def test_should_not_run_after_callbacks
        ran_callback = false
        @machine.after_transition { ran_callback = true }
        
        @record.valid?
        assert !ran_callback
      end
      
      def test_should_not_run_after_callbacks_with_failures_disabled_if_validation_fails
        @model.class_eval do
          attr_accessor :seatbelt
          validates_presence_of :seatbelt
        end
        
        ran_callback = false
        @machine.after_transition { ran_callback = true }
        
        @record.valid?
        assert !ran_callback
      end
      
      def test_should_run_after_callbacks_with_failures_enabled_if_validation_fails
        @model.class_eval do
          attr_accessor :seatbelt
          validates_presence_of :seatbelt
        end
        
        ran_callback = false
        @machine.after_transition(:include_failures => true) { ran_callback = true }
        
        @record.valid?
        assert ran_callback
      end
    end
    
    class MachineWithEventAttributesOnSaveBangTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
        @machine.event :ignite do
          transition :parked => :idling
        end
        
        @record = @model.new
        @record.state = 'parked'
        @record.state_event = 'ignite'
      end
      
      def test_should_fail_if_event_is_invalid
        @record.state_event = 'invalid'
        assert_raise(ActiveRecord::RecordInvalid) { @record.save! }
      end
      
      def test_should_fail_if_event_has_no_transition
        @record.state = 'idling'
        assert_raise(ActiveRecord::RecordInvalid) { @record.save! }
      end
      
      def test_should_be_successful_if_event_has_transition
        assert_equal true, @record.save!
      end
      
      def test_should_run_before_callbacks
        ran_callback = false
        @machine.before_transition { ran_callback = true }
        
        @record.save!
        assert ran_callback
      end
      
      def test_should_run_before_callbacks_once
        before_count = 0
        @machine.before_transition { before_count += 1 }
        
        @record.save!
        assert_equal 1, before_count
      end
      
      def test_should_persist_new_state
        @record.save!
        assert_equal 'idling', @record.state
      end
      
      def test_should_run_after_callbacks
        ran_callback = false
        @machine.after_transition { ran_callback = true }
        
        @record.save!
        assert ran_callback
      end
      
      def test_should_not_run_after_callbacks_with_failures_disabled_if_fails
        @model.before_create {|record| false}
        
        ran_callback = false
        @machine.after_transition { ran_callback = true }
        
        begin; @record.save!; rescue; end
        assert !ran_callback
      end
      
      def test_should_run_after_callbacks_with_failures_enabled_if_fails
        @model.before_create {|record| false}
        
        ran_callback = false
        @machine.after_transition(:include_failures => true) { ran_callback = true }
        
        begin; @record.save!; rescue; end
        assert ran_callback
      end
    end
    
    class MachineWithEventAttributesOnCustomActionTest < ActiveRecord::TestCase
      def setup
        @superclass = new_model do
          def persist
            create_or_update
          end
        end
        @model = Class.new(@superclass)
        @machine = StateMachine::Machine.new(@model, :action => :persist)
        @machine.event :ignite do
          transition :parked => :idling
        end
        
        @record = @model.new
        @record.state = 'parked'
        @record.state_event = 'ignite'
      end
      
      def test_should_not_transition_on_valid?
        @record.valid?
        assert_equal 'parked', @record.state
      end
      
      def test_should_not_transition_on_save
        @record.save
        assert_equal 'parked', @record.state
      end
      
      def test_should_not_transition_on_save!
        @record.save!
        assert_equal 'parked', @record.state
      end
      
      def test_should_transition_on_custom_action
        @record.persist
        assert_equal 'idling', @record.state
      end
    end
    
    class MachineWithObserversTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
        @machine.state :parked, :idling
        @machine.event :ignite
        @record = @model.new(:state => 'parked')
        @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
      end
      
      def test_should_call_all_transition_callback_permutations
        callbacks = [
          :before_ignite_from_parked_to_idling,
          :before_ignite_from_parked,
          :before_ignite_to_idling,
          :before_ignite,
          :before_transition_state_from_parked_to_idling,
          :before_transition_state_from_parked,
          :before_transition_state_to_idling,
          :before_transition_state,
          :before_transition
        ]
        
        notified = false
        observer = new_observer(@model) do
          callbacks.each do |callback|
            define_method(callback) do |*args|
              notifications << callback
            end
          end
        end
        
        instance = observer.instance
        
        @transition.perform
        assert_equal callbacks, instance.notifications
      end
      
      def test_should_pass_record_and_transition_to_before_callbacks
        observer = new_observer(@model) do
          def before_transition(*args)
            notifications << args
          end
        end
        instance = observer.instance
        
        @transition.perform
        assert_equal [[@record, @transition]], instance.notifications
      end
      
      def test_should_pass_record_and_transition_to_after_callbacks
        observer = new_observer(@model) do
          def after_transition(*args)
            notifications << args
          end
        end
        instance = observer.instance
        
        @transition.perform
        assert_equal [[@record, @transition]], instance.notifications
      end
      
      def test_should_call_methods_outside_the_context_of_the_record
        observer = new_observer(@model) do
          def before_ignite(*args)
            notifications << self
          end
        end
        instance = observer.instance
        
        @transition.perform
        assert_equal [instance], instance.notifications
      end
    end
    
    class MachineWithNamespacedObserversTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model, :state, :namespace => 'alarm')
        @machine.state :active, :off
        @machine.event :enable
        @record = @model.new(:state => 'off')
        @transition = StateMachine::Transition.new(@record, @machine, :enable, :off, :active)
      end
      
      def test_should_call_namespaced_before_event_method
        observer = new_observer(@model) do
          def before_enable_alarm(*args)
            notifications << args
          end
        end
        instance = observer.instance
        
        @transition.perform
        assert_equal [[@record, @transition]], instance.notifications
      end
      
      def test_should_call_namespaced_after_event_method
        observer = new_observer(@model) do
          def after_enable_alarm(*args)
            notifications << args
          end
        end
        instance = observer.instance
        
        @transition.perform
        assert_equal [[@record, @transition]], instance.notifications
      end
    end
    
    class MachineWithMixedCallbacksTest < ActiveRecord::TestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
        @machine.state :parked, :idling
        @machine.event :ignite
        @record = @model.new(:state => 'parked')
        @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
        
        @notifications = []
        
        # Create callbacks
        @machine.before_transition(lambda {@notifications << :callback_before_transition})
        @machine.after_transition(lambda {@notifications << :callback_after_transition})
        
        # Create observer callbacks
        observer = new_observer(@model) do
          def before_ignite(*args)
            notifications << :observer_before_ignite
          end
          
          def before_transition(*args)
            notifications << :observer_before_transition
          end
          
          def after_ignite(*args)
            notifications << :observer_after_ignite
          end
          
          def after_transition(*args)
            notifications << :observer_after_transition
          end
        end
        instance = observer.instance
        instance.notifications = @notifications
        
        @transition.perform
      end
      
      def test_should_invoke_callbacks_in_specific_order
        expected = [
          :callback_before_transition,
          :observer_before_ignite,
          :observer_before_transition,
          :callback_after_transition,
          :observer_after_ignite,
          :observer_after_transition
        ]
        
        assert_equal expected, @notifications
      end
    end
    
    if ActiveRecord.const_defined?(:Dirty) || ActiveRecord::AttributeMethods.const_defined?(:Dirty)
      class MachineWithLoopbackTest < ActiveRecord::TestCase
        def setup
          changed_attrs = nil
          
          @model = new_model do
            connection.add_column :foo, :updated_at, :datetime
            
            define_method(:before_update) do
              changed_attrs = changed_attributes.dup
            end
          end
          
          @machine = StateMachine::Machine.new(@model, :initial => :parked)
          @machine.event :park
          
          @record = @model.create(:updated_at => Time.now - 1)
          @timestamp = @record.updated_at
          
          @transition = StateMachine::Transition.new(@record, @machine, :park, :parked, :parked)
          @transition.perform
          
          @changed_attrs = changed_attrs
        end
        
        def test_should_include_state_in_changed_attributes
          @changed_attrs.delete('updated_at')
          
          expected = {'state' => 'parked'}
          assert_equal expected, @changed_attrs
        end
        
        def test_should_update_record
          assert_not_equal @timestamp, @record.updated_at
        end
      end
    end
    
    if ActiveRecord.const_defined?(:NamedScope)
      class MachineWithScopesTest < ActiveRecord::TestCase
        def setup
          @model = new_model
          @machine = StateMachine::Machine.new(@model)
          @machine.state :parked, :first_gear
          @machine.state :idling, :value => lambda {'idling'}
        end
        
        def test_should_create_singular_with_scope
          assert @model.respond_to?(:with_state)
        end
        
        def test_should_only_include_records_with_state_in_singular_with_scope
          parked = @model.create :state => 'parked'
          idling = @model.create :state => 'idling'
          
          assert_equal [parked], @model.with_state(:parked)
        end
        
        def test_should_create_plural_with_scope
          assert @model.respond_to?(:with_states)
        end
        
        def test_should_only_include_records_with_states_in_plural_with_scope
          parked = @model.create :state => 'parked'
          idling = @model.create :state => 'idling'
          
          assert_equal [parked, idling], @model.with_states(:parked, :idling)
        end
        
        def test_should_create_singular_without_scope
          assert @model.respond_to?(:without_state)
        end
        
        def test_should_only_include_records_without_state_in_singular_without_scope
          parked = @model.create :state => 'parked'
          idling = @model.create :state => 'idling'
          
          assert_equal [parked], @model.without_state(:idling)
        end
        
        def test_should_create_plural_without_scope
          assert @model.respond_to?(:without_states)
        end
        
        def test_should_only_include_records_without_states_in_plural_without_scope
          parked = @model.create :state => 'parked'
          idling = @model.create :state => 'idling'
          first_gear = @model.create :state => 'first_gear'
          
          assert_equal [parked, idling], @model.without_states(:first_gear)
        end
        
        def test_should_allow_chaining_scopes
          parked = @model.create :state => 'parked'
          idling = @model.create :state => 'idling'
          
          assert_equal [idling], @model.without_state(:parked).with_state(:idling)
        end
      end
      
      class MachineWithScopesAndOwnerSubclassTest < ActiveRecord::TestCase
        def setup
          @model = new_model
          @machine = StateMachine::Machine.new(@model, :state)
          
          @subclass = Class.new(@model)
          @subclass_machine = @subclass.state_machine(:state) {}
          @subclass_machine.state :parked, :idling, :first_gear
        end
        
        def test_should_only_include_records_with_subclass_states_in_with_scope
          parked = @subclass.create :state => 'parked'
          idling = @subclass.create :state => 'idling'
          
          assert_equal [parked, idling], @subclass.with_states(:parked, :idling)
        end
        
        def test_should_only_include_records_without_subclass_states_in_without_scope
          parked = @subclass.create :state => 'parked'
          idling = @subclass.create :state => 'idling'
          first_gear = @subclass.create :state => 'first_gear'
          
          assert_equal [parked, idling], @subclass.without_states(:first_gear)
        end
      end
      
      class MachineWithComplexPluralizationScopesTest < ActiveRecord::TestCase
        def setup
          @model = new_model
          @machine = StateMachine::Machine.new(@model, :status)
        end
        
        def test_should_create_singular_with_scope
          assert @model.respond_to?(:with_status)
        end
        
        def test_should_create_plural_with_scope
          assert @model.respond_to?(:with_statuses)
        end
      end
    end
    
    if Object.const_defined?(:I18n)
      class MachineWithInternationalizationTest < ActiveRecord::TestCase
        def setup
          I18n.backend = I18n::Backend::Simple.new
          
          # Initialize the backend
          I18n.backend.translate(:en, 'activerecord.errors.messages.invalid_transition', :event => 'ignite', :value => 'idling')
          
          @model = new_model
        end
        
        def test_should_invalidate_using_i18n_default
          I18n.backend.store_translations(:en, {
            :activerecord => {
              :errors => {
                :messages => {
                  :invalid_transition => 'cannot {{event}}'
                }
              }
            }
          })
          
          machine = StateMachine::Machine.new(@model)
          machine.state :parked, :idling
          event = StateMachine::Event.new(machine, :ignite)
          
          record = @model.new(:state => 'idling')
          
          machine.invalidate(record, :state, :invalid_transition, [[:event, :ignite]])
          assert_equal ['State cannot ignite'], record.errors.full_messages
        end
        
        def test_should_invalidate_using_customized_i18n_key_if_specified
          I18n.backend.store_translations(:en, {
            :activerecord => {
              :errors => {
                :messages => {
                  :bad_transition => 'cannot {{event}}'
                }
              }
            }
          })
          
          machine = StateMachine::Machine.new(@model, :messages => {:invalid_transition => :bad_transition})
          machine.state :parked, :idling
          
          record = @model.new(:state => 'idling')
          
          machine.invalidate(record, :state, :invalid_transition, [[:event, :ignite]])
          assert_equal ['State cannot ignite'], record.errors.full_messages
        end
        
        def test_should_invalidate_using_customized_i18n_string_if_specified
          machine = StateMachine::Machine.new(@model, :messages => {:invalid_transition => 'cannot {{event}}'})
          machine.state :parked, :idling
          
          record = @model.new(:state => 'idling')
          
          machine.invalidate(record, :state, :invalid_transition, [[:event, :ignite]])
          assert_equal ['State cannot ignite'], record.errors.full_messages
        end
        
        def test_should_only_add_locale_once_in_load_path
          assert_equal 1, I18n.load_path.select {|path| path =~ %r{state_machine/integrations/active_record/locale\.rb$}}.length
          
          # Create another ActiveRecord model that will triger the i18n feature
          new_model
          
          assert_equal 1, I18n.load_path.select {|path| path =~ %r{state_machine/integrations/active_record/locale\.rb$}}.length
        end
      end
    else
      $stderr.puts 'Skipping ActiveRecord I18n tests. `gem install active_record` >= v2.2.0 and try again.'
    end
  end
rescue LoadError
  $stderr.puts "Skipping ActiveRecord tests. `gem install activerecord#{" -v #{ENV['AR_VERSION']}" if ENV['AR_VERSION']}` and try again."
end
