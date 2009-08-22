require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

begin
  # Load library
  require 'rubygems'
  
  gem 'sequel', ENV['SEQUEL_VERSION'] ? "=#{ENV['SEQUEL_VERSION']}" : '>=2.8.0'
  require 'sequel'
  require 'logger'
  
  # Establish database connection
  DB = Sequel.connect('sqlite:///', :loggers => [Logger.new("#{File.dirname(__FILE__)}/../../sequel.log")])
  
  module SequelTest
    class BaseTestCase < Test::Unit::TestCase
      def default_test
      end
      
      protected
        # Creates a new Sequel model (and the associated table)
        def new_model(auto_migrate = true, &block)
          DB.create_table! :foo do
            primary_key :id
            column :state, :string
          end if auto_migrate
          model = Class.new(Sequel::Model(:foo)) do
            self.raise_on_save_failure = false
            def self.name; 'SequelTest::Foo'; end
          end
          model.plugin(:validation_class_methods) if model.respond_to?(:plugin)
          model.plugin(:hook_class_methods) if model.respond_to?(:plugin)
          model.class_eval(&block) if block_given?
          model
        end
    end
    
    class IntegrationTest < BaseTestCase
      def test_should_match_if_class_inherits_from_sequel
        assert StateMachine::Integrations::Sequel.matches?(new_model)
      end
      
      def test_should_not_match_if_class_does_not_inherit_from_sequel
        assert !StateMachine::Integrations::Sequel.matches?(Class.new)
      end
    end
    
    class MachineByDefaultTest < BaseTestCase
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
    end
    
    class MachineTest < BaseTestCase
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
        
        assert_equal [parked], @model.with_state(:parked).all
      end
      
      def test_should_create_plural_with_scope
        assert @model.respond_to?(:with_states)
      end
      
      def test_should_only_include_records_with_states_in_plural_with_scope
        parked = @model.create :state => 'parked'
        idling = @model.create :state => 'idling'
        
        assert_equal [parked, idling], @model.with_states(:parked, :idling).all
      end
      
      def test_should_create_singular_without_scope
        assert @model.respond_to?(:without_state)
      end
      
      def test_should_only_include_records_without_state_in_singular_without_scope
        parked = @model.create :state => 'parked'
        idling = @model.create :state => 'idling'
        
        assert_equal [parked], @model.without_state(:idling).all
      end
      
      def test_should_create_plural_without_scope
        assert @model.respond_to?(:without_states)
      end
      
      def test_should_only_include_records_without_states_in_plural_without_scope
        parked = @model.create :state => 'parked'
        idling = @model.create :state => 'idling'
        first_gear = @model.create :state => 'first_gear'
        
        assert_equal [parked, idling], @model.without_states(:first_gear).all
      end
      
      def test_should_allow_chaining_scopes_and_fitlers
        parked = @model.create :state => 'parked'
        idling = @model.create :state => 'idling'
        
        assert_equal [idling], @model.without_state(:parked).filter(:state => 'idling').all
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
        record = @model.new
        record.state = 'parked'
        
        @machine.invalidate(record, :state, :invalid_transition, [[:event, :park]])
        
        assert_equal ['cannot transition via "park"'], record.errors.on(:state)
      end
      
      def test_should_auto_prefix_custom_attributes_on_invalidation
        record = @model.new
        @machine.invalidate(record, :event, :invalid)
        
        assert_equal ['is invalid'], record.errors.on(:state_event)
      end
      
      def test_should_clear_errors_on_reset
        record = @model.new
        record.state = 'parked'
        record.errors.add(:state, 'is invalid')
        
        @machine.reset(record)
        assert_nil record.errors.on(:id)
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
    
    class MachineUnmigratedTest < BaseTestCase
      def setup
        @model = new_model(false)
      end
      
      def test_should_allow_machine_creation
        assert_nothing_raised { StateMachine::Machine.new(@model) }
      end
    end
    
    class MachineWithStaticInitialStateTest < BaseTestCase
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
      
      def test_should_not_have_any_changed_columns
        record = @model.new
        assert record.changed_columns.empty?
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
        record.set({})
        assert_equal 'idling', record.state
      end
    end
    
    class MachineWithDynamicInitialStateTest < BaseTestCase
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
      
      def test_should_not_have_any_changed_columns
        record = @model.new
        assert record.changed_columns.empty?
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
        record.set({})
        assert_equal 'idling', record.state
      end
    end
    
    class MachineWithColumnDefaultTest < BaseTestCase
      def setup
        @model = new_model
        DB.alter_table :foo do
          add_column :status, :string, :default => 'idling'
        end
        @model.class_eval { get_db_schema(true) }
        
        @machine = StateMachine::Machine.new(@model, :status, :initial => :parked)
        @record = @model.new
      end
      
      def test_should_use_machine_default
        assert_equal 'parked', @record.status
      end
    end
    
    class MachineWithNonColumnStateAttributeUndefinedTest < BaseTestCase
      def setup
        @model = new_model do
          def initialize
            # Skip attribute initialization
            @initialized_state_machines = true
            super
          end
        end
        
        @machine = StateMachine::Machine.new(@model, :status, :initial => 'parked')
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
    end
    
    class MachineWithNonColumnStateAttributeDefinedTest < BaseTestCase
      def setup
        @model = new_model do
          attr_accessor :status
        end
        
        @machine = StateMachine::Machine.new(@model, :status, :initial => 'parked')
        @record = @model.new
      end
      
      def test_should_set_initial_state_on_created_object
        assert_equal 'parked', @record.status
      end
    end
    
    class MachineWithComplexPluralizationTest < BaseTestCase
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
    
    class MachineWithOwnerSubclassTest < BaseTestCase
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
        
        assert_equal [parked, idling], @subclass.with_states(:parked, :idling).all
      end
      
      def test_should_only_include_records_without_subclass_states_in_without_scope
        parked = @subclass.create :state => 'parked'
        idling = @subclass.create :state => 'idling'
        first_gear = @subclass.create :state => 'first_gear'
        
        assert_equal [parked, idling], @subclass.without_states(:first_gear).all
      end
    end
    
    class MachineWithCustomAttributeTest < BaseTestCase
      def setup
        @model = new_model do
          alias_method :vehicle_status, :state
          alias_method :vehicle_status=, :state=
        end
        
        @machine = StateMachine::Machine.new(@model, :status, :attribute => :vehicle_status)
        @machine.state :parked
        
        @record = @model.new
      end
      
      def test_should_add_validation_errors_to_custom_attribute
        @record.vehicle_status = 'invalid'
        
        assert !@record.valid?
        assert_equal ['is invalid'], @record.errors.on(:vehicle_status)
        
        @record.vehicle_status = 'parked'
        assert @record.valid?
      end
    end
    
    class MachineWithInitializedStateTest < BaseTestCase
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
          self.strict_param_setting = false
          set_restricted_columns :state
        end
        
        record = @model.new(:state => 'idling')
        assert_equal 'parked', record.state
      end
    end
    
    class MachineWithCallbacksTest < BaseTestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model)
        @machine.state :parked, :idling
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
      
      def test_should_pass_transition_to_before_callbacks_with_one_argument
        transition = nil
        @machine.before_transition(lambda {|arg| transition = arg})
        
        @transition.perform
        assert_equal @transition, transition
      end
      
      def test_should_pass_transition_to_before_callbacks_with_multiple_arguments
        callback_args = nil
        @machine.before_transition(lambda {|*args| callback_args = args})
        
        @transition.perform
        assert_equal [@transition], callback_args
      end
      
      def test_should_run_before_callbacks_within_the_context_of_the_record
        context = nil
        @machine.before_transition(lambda {context = self})
        
        @transition.perform
        assert_equal @record, context
      end
      
      def test_should_run_after_callbacks
        called = false
        @machine.after_transition(lambda {called = true})
        
        @transition.perform
        assert called
      end
      
      def test_should_pass_transition_to_after_callbacks_with_multiple_arguments
        callback_args = nil
        @machine.after_transition(lambda {|*args| callback_args = args})
        
        @transition.perform
        assert_equal [@transition], callback_args
      end
      
      def test_should_run_after_callbacks_with_the_context_of_the_record
        context = nil
        @machine.after_transition(lambda {context = self})
        
        @transition.perform
        assert_equal @record, context
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
    
    class MachineWithLoopbackTest < BaseTestCase
      def setup
        changed_columns = nil
        
        @model = new_model do
          # Simulate timestamps plugin
          define_method(:before_update) do
            changed_columns = self.changed_columns.dup
            
            super()
            self.updated_at = Time.now if changed_columns.any?
          end
        end
        
        DB.alter_table :foo do
          add_column :updated_at, :datetime
        end
        @model.class_eval { get_db_schema(true) }
        
        @machine = StateMachine::Machine.new(@model, :initial => :parked)
        @machine.event :park
        
        @record = @model.create(:updated_at => Time.now - 1)
        @timestamp = @record.updated_at
        
        @transition = StateMachine::Transition.new(@record, @machine, :park, :parked, :parked)
        @transition.perform
        
        @changed_columns = changed_columns
      end
      
      def test_should_include_state_in_changed_columns
        assert_equal [:state], @changed_columns
      end
      
      def test_should_update_record
        assert_not_equal @timestamp, @record.updated_at
      end
    end
    
    class MachineWithValidationsTest < BaseTestCase
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
        assert_equal ['state is invalid'], @record.errors.full_messages
      end
    end
    
    class MachineWithStateDrivenValidationsTest < BaseTestCase
      def setup
        @model = new_model do
          attr_accessor :seatbelt
        end
        
        @machine = StateMachine::Machine.new(@model)
        @machine.state :first_gear do
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
        record = @model.new(:state => 'first_gear', :seatbelt => true)
        assert record.valid?
      end
    end
    
    class MachineWithEventAttributesOnValidationTest < BaseTestCase
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
        assert_equal ['state_event is invalid'], @record.errors.full_messages
      end
      
      def test_should_fail_if_event_has_no_transition
        @record.state = 'idling'
        assert !@record.valid?
        assert_equal ['state_event cannot transition when idling'], @record.errors.full_messages
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
    
    class MachineWithEventAttributesOnSaveTest < BaseTestCase
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
        assert !@record.save
      end
      
      def test_should_fail_if_event_has_no_transition
        @record.state = 'idling'
        assert !@record.save
      end
      
      def test_should_be_successful_if_event_has_transition
        assert @record.save
      end
      
      def test_should_run_before_callbacks
        ran_callback = false
        @machine.before_transition { ran_callback = true }
        
        @record.save
        assert ran_callback
      end
      
      def test_should_run_before_callbacks_once
        before_count = 0
        @machine.before_transition { before_count += 1 }
        
        @record.save
        assert_equal 1, before_count
      end
      
      def test_should_persist_new_state
        @record.save
        assert_equal 'idling', @record.state
      end
      
      def test_should_run_after_callbacks
        ran_callback = false
        @machine.after_transition { ran_callback = true }
        
        @record.save
        assert ran_callback
      end
      
      def test_should_not_run_after_callbacks_with_failures_disabled_if_fails
        @model.before_create {|record| false}
        
        ran_callback = false
        @machine.after_transition { ran_callback = true }
        
        @record.save
        assert !ran_callback
      end
      
      def test_should_run_after_callbacks_with_failures_enabled_if_fails
        @model.before_create {|record| false}
        
        ran_callback = false
        @machine.after_transition(:include_failures => true) { ran_callback = true }
        
        @record.save
        assert ran_callback
      end
    end
    
    class MachineWithEventAttributesOnCustomActionTest < BaseTestCase
      def setup
        @superclass = new_model do
          def persist
            save
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
      
      def test_should_transition_on_custom_action
        @record.persist
        assert_equal 'idling', @record.state
      end
    end
  end
rescue LoadError
  $stderr.puts "Skipping Sequel tests. `gem install sequel#{" -v #{ENV['SEQUEL_VERSION']}" if ENV['SEQUEL_VERSION']}` and try again."
end
