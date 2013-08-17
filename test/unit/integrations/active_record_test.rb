require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

require 'active_record'

FIXTURES_ROOT = File.dirname(__FILE__) + '/../../fixtures/'

# Load TestCase helpers
require 'active_support/test_case'
require 'active_record/fixtures'

begin
  require 'active_record/test_case'
rescue LoadError
  class ActiveRecord::TestCase < ActiveSupport::TestCase
    self.fixture_path = FIXTURES_ROOT
    self.use_instantiated_fixtures = false
    self.use_transactional_fixtures = true
  end
end

require 'active_record/version'
if ActiveRecord::VERSION::MAJOR >= 4
  require 'rails/observers/activerecord/active_record'
  require 'active_record/mass_assignment_security'
end

# Establish database connection
ActiveRecord::Base.establish_connection('adapter' => RUBY_PLATFORM == 'java' ? 'jdbcsqlite3' : 'sqlite3', 'database' => ':memory:')
ActiveRecord::Base.logger = Logger.new("#{File.dirname(__FILE__)}/../../active_record.log")

module ActiveRecordTest
  class BaseTestCase < ActiveRecord::TestCase
    def default_test
    end
    
    protected
      # Creates a new ActiveRecord model (and the associated table)
      def new_model(create_table = :foo, &block)
        name = create_table || :foo
        table_name = "#{name}_#{rand(1000000)}"
        
        model = Class.new(ActiveRecord::Base) do
          self.table_name = table_name.to_s
          connection.create_table(table_name, :force => true) {|t| t.string(:state)} if create_table
          
          (class << self; self; end).class_eval do
            define_method(:name) { "ActiveRecordTest::#{name.to_s.capitalize}" }
          end
        end
        model.class_eval(&block) if block_given?
        model.reset_column_information if create_table
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
        
        (class << observer; self; end).class_eval do
          define_method(:name) do
            "#{model.name}Observer"
          end
        end
        
        observer.observe(model)
        observer.class_eval(&block) if block_given?
        observer
      end
  end
  
  class IntegrationTest < BaseTestCase
    def test_should_have_an_integration_name
      assert_equal :active_record, StateMachine::Integrations::ActiveRecord.integration_name
    end
    
    def test_should_be_available
      assert StateMachine::Integrations::ActiveRecord.available?
    end
    
    def test_should_match_if_class_inherits_from_active_record
      assert StateMachine::Integrations::ActiveRecord.matches?(new_model)
    end
    
    def test_should_not_match_if_class_does_not_inherit_from_active_record
      assert !StateMachine::Integrations::ActiveRecord.matches?(Class.new)
    end
    
    def test_should_have_defaults
      assert_equal({:action => :save}, StateMachine::Integrations::ActiveRecord.defaults)
    end
    
    def test_should_have_a_locale_path
      assert_not_nil StateMachine::Integrations::ActiveRecord.locale_path
    end
  end
  
  class MachineWithoutDatabaseTest < BaseTestCase
    def setup
      @model = new_model(false) do
        # Simulate the database not being available entirely
        def self.connection
          raise ActiveRecord::ConnectionNotEstablished
        end
        
        def self.connected?
          false
        end
      end
    end
    
    def test_should_allow_machine_creation
      assert_nothing_raised { StateMachine::Machine.new(@model) }
    end
  end
  
  class MachineUnmigratedTest < BaseTestCase
    def setup
      @model = new_model(false)
      
      # Drop the table so that it definitely doesn't exist
      @model.connection.drop_table(@model.table_name) if @model.table_exists?
    end
    
    def test_should_allow_machine_creation
      assert_nothing_raised { StateMachine::Machine.new(@model) }
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
    
    def test_should_create_notifier_before_callback
      assert_equal 1, @machine.callbacks[:before].size
    end
    
    def test_should_create_notifier_after_callback
      assert_equal 1, @machine.callbacks[:after].size
    end
  end
  
  class MachineWithStatesTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model)
      @machine.state :first_gear
    end
    
    def test_should_humanize_name
      assert_equal 'first gear', @machine.state(:first_gear).human_name
    end
  end
  
  class MachineWithStaticInitialStateTest < BaseTestCase
    def setup
      @model = new_model(:vehicle) do
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
    
    def test_should_set_attributes_prior_to_initialize_block
      state = nil
      @model.new do |record|
        state = record.state
      end
      
      assert_equal 'parked', state
    end
    
    def test_should_set_attributes_prior_to_after_initialize_hook
      state = nil
      @model.class_eval {define_method(:after_initialize) {}} if ActiveRecord::VERSION::MAJOR <= 2
      @model.after_initialize do |record|
        state = record.state
      end
      @model.new
      assert_equal 'parked', state
    end
    
    def test_should_set_initial_state_before_setting_attributes
      @model.class_eval do
        attr_accessor :state_during_setter
        
        remove_method :value=
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
    
    def test_should_persist_initial_state
      record = @model.new
      record.save
      record.reload
      assert_equal 'parked', record.state
    end
    
    unless ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 0
      def test_should_persist_initial_state_on_dup
        record = @model.create.dup
        record.save
        record.reload
        assert_equal 'parked', record.state
      end
    end
    
    def test_should_use_stored_values_when_loading_from_database
      @machine.state :idling
      
      record = @model.find(@model.create(:state => 'idling').id)
      assert_equal 'idling', record.state
    end
    
    def test_should_use_stored_values_when_loading_from_database_with_nil_state
      @machine.state nil
      
      record = @model.find(@model.create(:state => nil).id)
      assert_nil record.state
    end
    
    def test_should_use_stored_values_when_loading_for_many_association
      @machine.state :idling
      
      @model.connection.add_column @model.table_name, :owner_id, :integer
      @model.reset_column_information
      ActiveRecordTest.const_set('Vehicle', @model)
      
      owner_model = new_model(:owner) do
        has_many :vehicles, :class_name => 'ActiveRecordTest::Vehicle'
      end
      ActiveRecordTest.const_set('Owner', owner_model)
      
      owner = owner_model.create
      record = @model.create(:state => 'idling', :owner_id => owner.id)
      assert_equal 'idling', owner.vehicles[0].state
    end
    
    def test_should_use_stored_values_when_loading_for_one_association
      @machine.state :idling
      
      @model.connection.add_column @model.table_name, :owner_id, :integer
      @model.reset_column_information
      ActiveRecordTest.const_set('Vehicle', @model)
      
      owner_model = new_model(:owner) do
        has_one :vehicle, :class_name => 'ActiveRecordTest::Vehicle'
      end
      ActiveRecordTest.const_set('Owner', owner_model)
      
      owner = owner_model.create
      record = @model.create(:state => 'idling', :owner_id => owner.id)
      assert_equal 'idling', owner.vehicle.state
    end
    
    def test_should_use_stored_values_when_loading_for_belongs_to_association
      @machine.state :idling
      
      ActiveRecordTest.const_set('Vehicle', @model)
      
      driver_model = new_model(:driver) do
        connection.add_column table_name, :vehicle_id, :integer
        
        belongs_to :vehicle, :class_name => 'ActiveRecordTest::Vehicle'
      end

      ActiveRecordTest.const_set('Driver', driver_model)
      
      record = @model.create(:state => 'idling')
      driver = driver_model.create(:vehicle_id => record.id)
      assert_equal 'idling', driver.vehicle.state
    end
    
    def teardown
      ActiveRecordTest.class_eval do
        remove_const('Vehicle') if defined?(ActiveRecordTest::Vehicle)
        remove_const('Owner') if defined?(ActiveRecordTest::Owner)
        remove_const('Driver') if defined?(ActiveRecordTest::Driver)
      end
      ActiveSupport::Dependencies.clear if defined?(ActiveSupport::Dependencies)
      super
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
    
    def test_should_set_attributes_prior_to_initialize_block
      state = nil
      @model.new do |record|
        state = record.state
      end
      
      assert_equal 'parked', state
    end
    
    def test_should_set_attributes_prior_to_after_initialize_hook
      state = nil
      @model.class_eval {define_method(:after_initialize) {}} if ActiveRecord::VERSION::MAJOR <= 2
      @model.after_initialize do |record|
        state = record.state
      end
      @model.new
      assert_equal 'parked', state
    end
    
    def test_should_set_initial_state_after_setting_attributes
      @model.class_eval do
        attr_accessor :state_during_setter
        
        remove_method :value=
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
    
    def test_should_persist_initial_state
      record = @model.new
      record.save
      record.reload
      assert_equal 'parked', record.state
    end
    
    unless ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 0
      def test_should_persist_initial_state_on_dup
        record = @model.create.dup
        record.save
        record.reload
        assert_equal 'parked', record.state
      end
    end
    
    def test_should_use_stored_values_when_loading_from_database
      @machine.state :idling
      
      record = @model.find(@model.create(:state => 'idling').id)
      assert_equal 'idling', record.state
    end
    
    def test_should_use_stored_values_when_loading_from_database_with_nil_state
      @machine.state nil
      
      record = @model.find(@model.create(:state => nil).id)
      assert_nil record.state
    end
  end
  
  class MachineWithEventsTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model)
      @machine.event :shift_up
    end
    
    def test_should_humanize_name
      assert_equal 'shift up', @machine.event(:shift_up).human_name
    end
  end
  
  class MachineWithSameColumnDefaultTest < BaseTestCase
    def setup
      @original_stderr, $stderr = $stderr, StringIO.new
      
      @model = new_model do
        connection.add_column table_name, :status, :string, :default => 'parked'
      end
      @machine = StateMachine::Machine.new(@model, :status, :initial => :parked)
      @record = @model.new
    end
    
    def test_should_use_machine_default
      assert_equal 'parked', @record.status
    end
    
    def test_should_not_generate_a_warning
      assert_no_match(/have defined a different default/, $stderr.string)
    end
    
    def teardown
      $stderr = @original_stderr
      super
    end
  end
  
  class MachineWithDifferentColumnDefaultTest < BaseTestCase
    def setup
      @original_stderr, $stderr = $stderr, StringIO.new
      
      @model = new_model do
        connection.add_column table_name, :status, :string, :default => 'idling'
      end
      @machine = StateMachine::Machine.new(@model, :status, :initial => :parked)
      @record = @model.new
    end
    
    def test_should_use_machine_default
      assert_equal 'parked', @record.status
    end
    
    def test_should_generate_a_warning
      assert_match(/Both ActiveRecordTest::Foo and its :status machine have defined a different default for "status". Use only one or the other for defining defaults to avoid unexpected behaviors\./, $stderr.string)
    end
    
    def teardown
      $stderr = @original_stderr
      super
    end
  end
  
  class MachineWithDifferentIntegerColumnDefaultTest < BaseTestCase
    def setup
      @original_stderr, $stderr = $stderr, StringIO.new
      
      @model = new_model do
        connection.add_column table_name, :status, :integer, :default => 0
      end
      @machine = StateMachine::Machine.new(@model, :status, :initial => :parked)
      @machine.state :parked, :value => 1
      @record = @model.new
    end
    
    def test_should_use_machine_default
      assert_equal 1, @record.status
    end
    
    def test_should_generate_a_warning
      assert_match(/Both ActiveRecordTest::Foo and its :status machine have defined a different default for "status". Use only one or the other for defining defaults to avoid unexpected behaviors\./, $stderr.string)
    end
    
    def teardown
      $stderr = @original_stderr
      super
    end
  end
  
  class MachineWithConflictingPredicateTest < BaseTestCase
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
  
  class MachineWithConflictingStateNameTest < BaseTestCase
    def setup
      require 'stringio'
      @original_stderr, $stderr = $stderr, StringIO.new
      
      @model = new_model
    end
    
    def test_should_output_warning_with_same_machine_name
      @machine = StateMachine::Machine.new(@model)
      @machine.state :state
      
      assert_match(/^Instance method "state\?" is already defined in ActiveRecordTest::Foo, use generic helper instead.*\n$/, $stderr.string)
    end
    
    def test_should_output_warning_with_same_machine_attribute
      @machine = StateMachine::Machine.new(@model, :public_state, :attribute => :state)
      @machine.state :state
      
      assert_match(/^Instance method "state\?" is already defined in ActiveRecordTest::Foo, use generic helper instead.*\n$/, $stderr.string)
    end
    
    def teardown
      $stderr = @original_stderr
      super
    end
  end
  
  class MachineWithColumnStateAttributeTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model, :initial => :parked)
      @machine.other_states(:idling)
      
      @record = @model.new
    end
    
    def test_should_not_override_the_column_reader
      @record[:state] = 'parked'
      assert_equal 'parked', @record.state
    end
    
    def test_should_not_override_the_column_writer
      @record.state = 'parked'
      assert_equal 'parked', @record[:state]
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
  
  class MachineWithNonColumnStateAttributeUndefinedTest < BaseTestCase
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
    
    def test_should_not_define_a_column_for_the_attribute
      assert_nil @model.columns_hash['status']
    end
    
    def test_should_define_a_reader_attribute_for_the_attribute
      assert @record.respond_to?(:status)
    end
    
    def test_should_define_a_writer_attribute_for_the_attribute
      assert @record.respond_to?(:status=)
    end
    
    def test_should_define_an_attribute_predicate
      assert @record.respond_to?(:status?)
    end
  end
  
  class MachineWithNonColumnStateAttributeDefinedTest < BaseTestCase
    def setup
      @model = new_model do
        def status=(value)
          self['status'] = value
        end
        
        def status
          self['status']
        end
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
  
  class MachineWithAliasedAttributeTest < BaseTestCase
    def setup
      @model = new_model do
        alias_attribute :vehicle_status, :state
      end
      
      @machine = StateMachine::Machine.new(@model, :status, :attribute => :vehicle_status)
      @machine.state :parked
      
      @record = @model.new
    end
    
    def test_should_check_custom_attribute_for_predicate
      @record.vehicle_status = nil
      assert !@record.status?(:parked)
      
      @record.vehicle_status = 'parked'
      assert @record.status?(:parked)
    end
  end
  
  class MachineWithCustomAttributeTest < BaseTestCase
    def setup
      require 'stringio'
      @original_stderr, $stderr = $stderr, StringIO.new
      
      @model = new_model
      @machine = StateMachine::Machine.new(@model, :public_state, :attribute => :state)
      @record = @model.new
    end
    
    def test_should_not_delegate_attribute_predicate_with_different_attribute
      assert_raise(ArgumentError) { @record.public_state? }
    end
    
    def teardown
      $stderr = @original_stderr
      super
    end
  end
  
  class MachineWithInitializedStateTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model, :initial => :parked)
      @machine.state :idling
    end
    
    def test_should_allow_nil_initial_state_when_static
      @machine.state nil
      
      record = @model.new(:state => nil)
      assert_nil record.state
    end
    
    def test_should_allow_nil_initial_state_when_dynamic
      @machine.state nil
      
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
  
  class MachineMultipleTest < BaseTestCase
    def setup
      @model = new_model do
        connection.add_column table_name, :status, :string
      end
      @state_machine = StateMachine::Machine.new(@model, :initial => :parked)
      @status_machine = StateMachine::Machine.new(@model, :status, :initial => :idling)
    end
    
    def test_should_should_initialize_each_state
      record = @model.new
      assert_equal 'parked', record.state
      assert_equal 'idling', record.status
    end
  end
  
  class MachineWithLoopbackTest < BaseTestCase
    def setup
      @model = new_model do
        connection.add_column table_name, :updated_at, :datetime
      end
      
      @machine = StateMachine::Machine.new(@model, :initial => :parked)
      @machine.event :park
      
      @record = @model.create(:updated_at => Time.now - 1)
      @transition = StateMachine::Transition.new(@record, @machine, :park, :parked, :parked)
      
      @timestamp = @record.updated_at
      @transition.perform
    end
    
    if ActiveRecord.const_defined?(:Dirty) || ActiveRecord::AttributeMethods.const_defined?(:Dirty)
      def test_should_not_update_record
        assert_equal @timestamp, @record.updated_at
      end
    else
      def test_should_update_record
        assert_not_equal @timestamp, @record.updated_at
      end
    end
  end
  
  if ActiveRecord.const_defined?(:Dirty) || ActiveRecord::AttributeMethods.const_defined?(:Dirty)
    class MachineWithDirtyAttributesTest < BaseTestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model, :initial => :parked)
        @machine.event :ignite
        @machine.state :idling
        
        @record = @model.create
        
        @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
        @transition.perform(false)
      end
      
      def test_should_include_state_in_changed_attributes
        assert_equal %w(state), @record.changed
      end
      
      def test_should_track_attribute_change
        assert_equal %w(parked idling), @record.changes['state']
      end
      
      def test_should_not_reset_changes_on_multiple_transitions
        transition = StateMachine::Transition.new(@record, @machine, :ignite, :idling, :idling)
        transition.perform(false)
        
        assert_equal %w(parked idling), @record.changes['state']
      end
      
      def test_should_not_have_changes_when_loaded_from_database
        record = @model.find(@record.id)
        assert !record.changed?
      end
    end
    
    class MachineWithDirtyAttributesDuringLoopbackTest < BaseTestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model, :initial => :parked)
        @machine.event :park
        
        @record = @model.create
        
        @transition = StateMachine::Transition.new(@record, @machine, :park, :parked, :parked)
        @transition.perform(false)
      end
      
      def test_should_not_include_state_in_changed_attributes
        assert_equal [], @record.changed
      end
      
      def test_should_not_track_attribute_changes
        assert_equal nil, @record.changes['state']
      end
    end
    
    class MachineWithDirtyAttributesAndCustomAttributeTest < BaseTestCase
      def setup
        @model = new_model do
          connection.add_column table_name, :status, :string
        end
        @machine = StateMachine::Machine.new(@model, :status, :initial => :parked)
        @machine.event :ignite
        @machine.state :idling
        
        @record = @model.create
        
        @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
        @transition.perform(false)
      end
      
      def test_should_include_state_in_changed_attributes
        assert_equal %w(status), @record.changed
      end
      
      def test_should_track_attribute_change
        assert_equal %w(parked idling), @record.changes['status']
      end
      
      def test_should_not_reset_changes_on_multiple_transitions
        transition = StateMachine::Transition.new(@record, @machine, :ignite, :idling, :idling)
        transition.perform(false)
        
        assert_equal %w(parked idling), @record.changes['status']
      end
    end
    
    class MachineWithDirtyAttributeAndCustomAttributesDuringLoopbackTest < BaseTestCase
      def setup
        @model = new_model do
          connection.add_column table_name, :status, :string
        end
        @machine = StateMachine::Machine.new(@model, :status, :initial => :parked)
        @machine.event :park
        
        @record = @model.create
        
        @transition = StateMachine::Transition.new(@record, @machine, :park, :parked, :parked)
        @transition.perform(false)
      end
      
      def test_should_not_include_state_in_changed_attributes
        assert_equal [], @record.changed
      end
      
      def test_should_not_track_attribute_changes
        assert_equal nil, @record.changes['status']
      end
    end
    
    class MachineWithDirtyAttributeAndStateEventsTest < BaseTestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model, :initial => :parked)
        @machine.event :ignite
        
        @record = @model.create
        @record.state_event = 'ignite'
      end
      
      def test_should_not_include_state_in_changed_attributes
        assert_equal [], @record.changed
      end
      
      def test_should_not_track_attribute_change
        assert_equal nil, @record.changes['state']
      end
    end
  else
    $stderr.puts 'Skipping ActiveRecord Dirty tests.'
  end
  
  class MachineWithoutTransactionsTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model, :use_transactions => false)
    end
    
    def test_should_not_rollback_transaction_if_false
      @machine.within_transaction(@model.new) do
        @model.create
        false
      end
      
      assert_equal 1, @model.count
    end
    
    def test_should_not_rollback_transaction_if_true
      @machine.within_transaction(@model.new) do
        @model.create
        true
      end
      
      assert_equal 1, @model.count
    end
  end
  
  class MachineWithTransactionsTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model, :use_transactions => true)
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
  end
  
  class MachineWithCallbacksTest < BaseTestCase
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
      @machine.before_transition {called = true}
      
      @transition.perform
      assert called
    end
    
    def test_should_pass_record_to_before_callbacks_with_one_argument
      record = nil
      @machine.before_transition {|arg| record = arg}
      
      @transition.perform
      assert_equal @record, record
    end
    
    def test_should_pass_record_and_transition_to_before_callbacks_with_multiple_arguments
      callback_args = nil
      @machine.before_transition {|*args| callback_args = args}
      
      @transition.perform
      assert_equal [@record, @transition], callback_args
    end
    
    def test_should_run_before_callbacks_outside_the_context_of_the_record
      context = nil
      @machine.before_transition {context = self}
      
      @transition.perform
      assert_equal self, context
    end
    
    def test_should_run_after_callbacks
      called = false
      @machine.after_transition {called = true}
      
      @transition.perform
      assert called
    end
    
    def test_should_pass_record_to_after_callbacks_with_one_argument
      record = nil
      @machine.after_transition {|arg| record = arg}
      
      @transition.perform
      assert_equal @record, record
    end
    
    def test_should_pass_record_and_transition_to_after_callbacks_with_multiple_arguments
      callback_args = nil
      @machine.after_transition {|*args| callback_args = args}
      
      @transition.perform
      assert_equal [@record, @transition], callback_args
    end
    
    def test_should_run_after_callbacks_outside_the_context_of_the_record
      context = nil
      @machine.after_transition {context = self}
      
      @transition.perform
      assert_equal self, context
    end
    
    def test_should_run_after_callbacks_if_model_callback_added_prior_to_state_machine_definition
      model = new_model do
        after_save { nil }
      end
      machine = StateMachine::Machine.new(model, :initial => :parked)
      machine.other_states :idling
      machine.event :ignite
      after_called = false
      machine.after_transition {after_called = true}
      
      record = model.new(:state => 'parked')
      transition = StateMachine::Transition.new(record, machine, :ignite, :parked, :idling)
      transition.perform
      assert_equal true, after_called
    end
    
    def test_should_run_around_callbacks
      before_called = false
      after_called = false
      ensure_called = 0
      @machine.around_transition do |block|
        before_called = true
        begin
          block.call
        ensure
          ensure_called += 1
        end
        after_called = true
      end
      
      @transition.perform
      assert before_called
      assert after_called
      assert_equal ensure_called, 1
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
    
    def test_should_run_in_expected_order
      expected = [
        :before_transition, :before_validation, :after_validation,
        :before_save, :before_create, :after_create, :after_save,
        :after_transition
      ]
      
      callbacks = []
      @model.before_validation { callbacks << :before_validation }
      @model.after_validation { callbacks << :after_validation }
      @model.before_save { callbacks << :before_save }
      @model.before_create { callbacks << :before_create }
      @model.after_create { callbacks << :after_create }
      @model.after_save { callbacks << :after_save }
      if @model.respond_to?(:after_commit)
        @model.after_commit { callbacks << :after_commit }
        expected << :after_commit
      end
      
      @machine.before_transition { callbacks << :before_transition }
      @machine.after_transition { callbacks << :after_transition }
      
      @transition.perform
      
      assert_equal expected, callbacks
    end
  end
  
  class MachineWithFailedBeforeCallbacksTest < BaseTestCase
    def setup
      @callbacks = []
      
      @model = new_model
      @machine = StateMachine::Machine.new(@model)
      @machine.state :parked, :idling
      @machine.event :ignite
      @machine.before_transition {@callbacks << :before_1; false}
      @machine.before_transition {@callbacks << :before_2}
      @machine.after_transition {@callbacks << :after}
      @machine.around_transition {|block| @callbacks << :around_before; block.call; @callbacks << :around_after}
      
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
    
    def test_should_not_run_further_callbacks
      assert_equal [:before_1], @callbacks
    end
  end
  
  class MachineNestedActionTest < BaseTestCase
    def setup
      @callbacks = []
      
      @model = new_model
      @machine = StateMachine::Machine.new(@model)
      @machine.event :ignite do
        transition :parked => :idling
      end
      
      @record = @model.new(:state => 'parked')
    end
    
    def test_should_allow_transition_prior_to_creation_if_skipping_action
      record = @record
      @model.before_create { record.ignite(false) }
      result = @record.save
      
      assert_equal true, result
      assert_equal "idling", @record.state
      @record.reload
      assert_equal "idling", @record.state
    end
    
    def test_should_allow_transition_after_creation
      record = @record
      @model.after_create { record.ignite }
      result = @record.save
      
      assert_equal true, result
      assert_equal "idling", @record.state
      @record.reload
      assert_equal "idling", @record.state
    end
  end
  
  class MachineWithFailedActionTest < BaseTestCase
    def setup
      @model = new_model do
        validates_inclusion_of :state, :in => %w(first_gear)
      end
      
      @machine = StateMachine::Machine.new(@model)
      @machine.state :parked, :idling
      @machine.event :ignite
      
      @callbacks = []
      @machine.before_transition {@callbacks << :before}
      @machine.after_transition {@callbacks << :after}
      @machine.after_failure {@callbacks << :after_failure}
      @machine.around_transition {|block| @callbacks << :around_before; block.call; @callbacks << :around_after}
      
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
    
    def test_should_run_before_callbacks_and_after_callbacks_with_failures
      assert_equal [:before, :around_before, :after_failure], @callbacks
    end
  end
  
  class MachineWithFailedAfterCallbacksTest < BaseTestCase
    def setup
      @callbacks = []
      
      @model = new_model
      @machine = StateMachine::Machine.new(@model)
      @machine.state :parked, :idling
      @machine.event :ignite
      @machine.after_transition {@callbacks << :after_1; false}
      @machine.after_transition {@callbacks << :after_2}
      @machine.around_transition {|block| @callbacks << :around_before; block.call; @callbacks << :around_after}
      
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
      assert_equal [:around_before, :around_after, :after_1], @callbacks
    end
  end
  
  class MachineWithValidationsTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model)
      @machine.state :parked
      
      @record = @model.new
    end
    
    def test_should_invalidate_using_errors
      I18n.backend = I18n::Backend::Simple.new if Object.const_defined?(:I18n)
      @record.state = 'parked'
      
      @machine.invalidate(@record, :state, :invalid_transition, [[:event, 'park']])
      assert_equal ['State cannot transition via "park"'], @record.errors.full_messages
    end
    
    def test_should_auto_prefix_custom_attributes_on_invalidation
      @machine.invalidate(@record, :event, :invalid)
      
      assert_equal ['State event is invalid'], @record.errors.full_messages
    end
    
    def test_should_clear_errors_on_reset
      @record.state = 'parked'
      @record.errors.add(:state, 'is invalid')
      
      @machine.reset(@record)
      assert_equal [], @record.errors.full_messages
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
  
  class MachineWithValidationsAndCustomAttributeTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model, :status, :attribute => :state)
      @machine.state :parked
      
      @record = @model.new
    end
    
    def test_should_add_validation_errors_to_custom_attribute
      @record.state = 'invalid'
      
      assert !@record.valid?
      assert_equal ['State is invalid'], @record.errors.full_messages
      
      @record.state = 'parked'
      assert @record.valid?
    end
  end
  
  class MachineErrorsTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model)
      @record = @model.new
    end
    
    def test_should_be_able_to_describe_current_errors
      @record.errors.add(:id, 'cannot be blank')
      @record.errors.add(:state, 'is invalid')
      assert_equal ['Id cannot be blank', 'State is invalid'], @machine.errors_for(@record).split(', ').sort
    end
    
    def test_should_describe_as_halted_with_no_errors
      assert_equal 'Transition halted', @machine.errors_for(@record)
    end
  end
    
  class MachineWithStateDrivenValidationsTest < BaseTestCase
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
    
    def test_should_run_around_callbacks_before_yield
      ran_callback = false
      @machine.around_transition {|block| ran_callback = true; block.call }
      
      begin
        @record.valid?
      rescue ArgumentError
        raise if StateMachine::Transition.pause_supported?
      end
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
    
    def test_should_run_after_callbacks_if_validation_fails
      @model.class_eval do
        attr_accessor :seatbelt
        validates_presence_of :seatbelt
      end
      
      ran_callback = false
      @machine.after_failure { ran_callback = true }
      
      @record.valid?
      assert ran_callback
    end
    
    def test_should_not_run_around_callbacks_after_yield
      ran_callback = false
      @machine.around_transition {|block| block.call; ran_callback = true }
      
      begin
        @record.valid?
      rescue ArgumentError
        raise if StateMachine::Transition.pause_supported?
      end
      assert !ran_callback
    end
    
    def test_should_not_run_around_callbacks_after_yield_with_failures_disabled_if_validation_fails
      @model.class_eval do
        attr_accessor :seatbelt
        validates_presence_of :seatbelt
      end
      
      ran_callback = false
      @machine.around_transition {|block| block.call; ran_callback = true }
      
      @record.valid?
      assert !ran_callback
    end
    
    def test_should_not_run_before_transitions_within_transaction
      @machine.before_transition { @model.create; raise ActiveRecord::Rollback }
      
      begin
        @record.valid?
      rescue Exception
      end
      
      assert_equal 1, @model.count
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
      assert_equal false, @record.save
    end
    
    def test_should_fail_if_event_has_no_transition
      @record.state = 'idling'
      assert_equal false, @record.save
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
    
    def test_should_run_around_callbacks_before_yield
      ran_callback = false
      @machine.around_transition {|block| ran_callback = true; block.call }
      
      @record.save
      assert ran_callback
    end
    
    def test_should_run_around_callbacks_before_yield_once
      around_before_count = 0
      @machine.around_transition {|block| around_before_count += 1; block.call }
      
      @record.save
      assert_equal 1, around_before_count
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
      
      begin; @record.save; rescue; end
      assert !ran_callback
    end
    
    def test_should_run_failure_callbacks__if_fails
      @model.before_create {|record| false}
      
      ran_callback = false
      @machine.after_failure { ran_callback = true }
      
      begin; @record.save; rescue; end
      assert ran_callback
    end
    
    def test_should_not_run_around_callbacks_if_fails
      @model.before_create {|record| false}
      
      ran_callback = false
      @machine.around_transition {|block| block.call; ran_callback = true }
      
      begin; @record.save; rescue; end
      assert !ran_callback
    end
    
    def test_should_run_around_callbacks_after_yield
      ran_callback = false
      @machine.around_transition {|block| block.call; ran_callback = true }
      
      @record.save
      assert ran_callback
    end
    
    def test_should_run_before_transitions_within_transaction
      @machine.before_transition { @model.create; raise ActiveRecord::Rollback }
      
      begin
        @record.save
      rescue Exception
      end
      
      assert_equal 0, @model.count
    end
    
    def test_should_run_after_transitions_within_transaction
      @machine.after_transition { @model.create; raise ActiveRecord::Rollback }
      
      begin
        @record.save
      rescue Exception
      end
      
      assert_equal 0, @model.count
    end
    
    def test_should_run_around_transition_within_transaction
      @machine.around_transition { @model.create; raise ActiveRecord::Rollback }
      
      begin
        @record.save
      rescue Exception
      end
      
      assert_equal 0, @model.count
    end
    
    def test_should_allow_additional_transitions_to_new_state_in_after_transitions
      @machine.event :park do
        transition :idling => :parked
      end
      
      @machine.after_transition(:on => :ignite) { @record.park }
      
      @record.save
      assert_equal 'parked', @record.state
      
      @record.reload
      assert_equal 'parked', @record.state
    end
    
    def test_should_allow_additional_transitions_to_previous_state_in_after_transitions
      @machine.event :shift_up do
        transition :idling => :first_gear
      end
      
      @machine.after_transition(:on => :ignite) { @record.shift_up }
      
      @record.save
      assert_equal 'first_gear', @record.state
      
      @record.reload
      assert_equal 'first_gear', @record.state
    end
    
    def test_should_return_nil_on_manual_rollback
      @machine.before_transition { raise ActiveRecord::Rollback }
      
      assert_equal nil, @record.save
    end
  end
  
  if ActiveRecord::VERSION::MAJOR >= 3 || ActiveRecord::VERSION::MINOR >= 3
    class MachineWithEventAttributesOnAutosaveTest < BaseTestCase
      def setup
        @vehicle_model = new_model(:vehicle) do
          connection.add_column table_name, :owner_id, :integer
        end
        ActiveRecordTest.const_set('Vehicle', @vehicle_model)
        
        @owner_model = new_model(:owner)
        ActiveRecordTest.const_set('Owner', @owner_model)
        
        machine = StateMachine::Machine.new(@vehicle_model)
        machine.event :ignite do
          transition :parked => :idling
        end
        
        @owner = @owner_model.create
        @vehicle = @vehicle_model.create(:state => 'parked', :owner_id => @owner.id)
      end
      
      def test_should_persist_has_one_autosave
        @owner_model.has_one :vehicle, :class_name => 'ActiveRecordTest::Vehicle', :autosave => true
        @owner.vehicle.state_event = 'ignite'
        @owner.save
        
        @vehicle.reload
        assert_equal 'idling', @vehicle.state
      end
      
      def test_should_persist_has_many_autosave
        @owner_model.has_many :vehicles, :class_name => 'ActiveRecordTest::Vehicle', :autosave => true
        @owner.vehicles[0].state_event = 'ignite'
        @owner.save
        
        @vehicle.reload
        assert_equal 'idling', @vehicle.state
      end
      
      def teardown
        ActiveRecordTest.class_eval do
          remove_const('Vehicle')
          remove_const('Owner')
        end
        ActiveSupport::Dependencies.clear if defined?(ActiveSupport::Dependencies)
        super
      end
    end
  end
  
  class MachineWithEventAttributesOnSaveBangTest < BaseTestCase
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
    
    def test_should_run_around_callbacks_before_yield
      ran_callback = false
      @machine.around_transition {|block| ran_callback = true; block.call }
      
      @record.save!
      assert ran_callback
    end
    
    def test_should_run_around_callbacks_before_yield_once
      around_before_count = 0
      @machine.around_transition {|block| around_before_count += 1; block.call }
      
      @record.save!
      assert_equal 1, around_before_count
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
    
    def test_should_run_around_callbacks_after_yield
      ran_callback = false
      @machine.around_transition {|block| block.call; ran_callback = true }
      
      @record.save!
      assert ran_callback
    end
  end
  
  class MachineWithEventAttributesOnCustomActionTest < BaseTestCase
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
  
  class MachineWithObserversTest < BaseTestCase
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
    
    def test_should_call_no_transition_callbacks_when_observers_disabled
      return unless ActiveRecord::VERSION::MAJOR >= 3 && ActiveRecord::VERSION::MINOR >= 1
      
      callbacks = [
        :before_ignite,
        :before_transition
      ]
      
      observer = new_observer(@model) do
        callbacks.each do |callback|
          define_method(callback) do |*args|
            notifications << callback
          end
        end
      end
      
      instance = observer.instance
      
      @model.observers.disable(observer) do
        @transition.perform
      end
      
      assert_equal [], instance.notifications
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
    
    def test_should_continue_to_handle_non_state_machine_callbacks
      observer = new_observer(@model) do
        def before_save(object)
          notifications << [:before_save, object]
        end
        
        def before_ignite(*args)
          notifications << :before_ignite
        end
      end
      
      instance = observer.instance
      
      @transition.perform
      assert_equal [:before_ignite, [:before_save, @record]], instance.notifications
    end
    
    def test_should_support_nil_from_states
      callbacks = [
        :before_ignite_from_nil_to_idling,
        :before_ignite_from_nil,
        :before_transition_state_from_nil_to_idling,
        :before_transition_state_from_nil
      ]
      
      observer = new_observer(@model) do
        callbacks.each do |callback|
          define_method(callback) do |*args|
            notifications << callback
          end
        end
      end
      
      instance = observer.instance
      
      transition = StateMachine::Transition.new(@record, @machine, :ignite, nil, :idling)
      transition.perform
      assert_equal callbacks, instance.notifications
    end
    
    def test_should_support_nil_to_states
      callbacks = [
        :before_ignite_from_parked_to_nil,
        :before_ignite_to_nil,
        :before_transition_state_from_parked_to_nil,
        :before_transition_state_to_nil
      ]
      
      observer = new_observer(@model) do
        callbacks.each do |callback|
          define_method(callback) do |*args|
            notifications << callback
          end
        end
      end
      
      instance = observer.instance
      
      transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, nil)
      transition.perform
      assert_equal callbacks, instance.notifications
    end
  end
  
  class MachineWithNamespacedObserversTest < BaseTestCase
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
  
  class MachineWithFailureCallbacksTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model)
      @machine.state :parked, :idling
      @machine.event :ignite
      @record = @model.new(:state => 'parked')
      @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
      
      @notifications = []
      
      # Create callbacks
      @machine.before_transition {false}
      @machine.after_failure {@notifications << :callback_after_failure}
      
      # Create observer callbacks
      observer = new_observer(@model) do
        def after_failure_to_ignite(*args)
          notifications << :observer_after_failure_ignite
        end
        
        def after_failure_to_transition(*args)
          notifications << :observer_after_failure_transition
        end
      end
      instance = observer.instance
      instance.notifications = @notifications
      
      @transition.perform
    end
    
    def test_should_invoke_callbacks_in_specific_order
      expected = [
        :callback_after_failure,
        :observer_after_failure_ignite,
        :observer_after_failure_transition
      ]
      
      assert_equal expected, @notifications
    end
  end
  
  class MachineWithMixedCallbacksTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachine::Machine.new(@model)
      @machine.state :parked, :idling
      @machine.event :ignite
      @record = @model.new(:state => 'parked')
      @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
      
      @notifications = []
      
      # Create callbacks
      @machine.before_transition {@notifications << :callback_before_transition}
      @machine.after_transition {@notifications << :callback_after_transition}
      @machine.around_transition do |block|
        @notifications << :callback_around_before_transition
        block.call
        @notifications << :callback_arond_after_transition
      end
      
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
        :callback_around_before_transition,
        :observer_before_ignite,
        :observer_before_transition,
        :callback_arond_after_transition,
        :callback_after_transition,
        :observer_after_ignite,
        :observer_after_transition
      ]
      
      assert_equal expected, @notifications
    end
  end
  
  if ActiveRecord::VERSION::MAJOR >= 3
    class MachineWithScopesTest < BaseTestCase
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
        @model.create :state => 'idling'
        
        assert_equal [parked], @model.with_state(:parked).find(:all)
      end
      
      def test_should_create_plural_with_scope
        assert @model.respond_to?(:with_states)
      end
      
      def test_should_only_include_records_with_states_in_plural_with_scope
        parked = @model.create :state => 'parked'
        idling = @model.create :state => 'idling'
        
        assert_equal [parked, idling], @model.with_states(:parked, :idling).find(:all)
      end
      
      def test_should_allow_lookup_by_string_name
        parked = @model.create :state => 'parked'
        idling = @model.create :state => 'idling'
        
        assert_equal [parked, idling], @model.with_states('parked', 'idling').find(:all)
      end
      
      def test_should_create_singular_without_scope
        assert @model.respond_to?(:without_state)
      end
      
      def test_should_only_include_records_without_state_in_singular_without_scope
        parked = @model.create :state => 'parked'
        idling = @model.create :state => 'idling'
        
        assert_equal [parked], @model.without_state(:idling).find(:all)
      end
      
      def test_should_create_plural_without_scope
        assert @model.respond_to?(:without_states)
      end
      
      def test_should_only_include_records_without_states_in_plural_without_scope
        parked = @model.create :state => 'parked'
        idling = @model.create :state => 'idling'
        first_gear = @model.create :state => 'first_gear'
        
        assert_equal [parked, idling], @model.without_states(:first_gear).find(:all)
      end
      
      def test_should_allow_chaining_scopes
        parked = @model.create :state => 'parked'
        idling = @model.create :state => 'idling'
        
        assert_equal [idling], @model.without_state(:parked).with_state(:idling).find(:all)
      end
    end
    
    class MachineWithScopesAndOwnerSubclassTest < BaseTestCase
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
        
        assert_equal [parked, idling], @subclass.with_states(:parked, :idling).find(:all)
      end
      
      def test_should_only_include_records_without_subclass_states_in_without_scope
        parked = @subclass.create :state => 'parked'
        idling = @subclass.create :state => 'idling'
        first_gear = @subclass.create :state => 'first_gear'
        
        assert_equal [parked, idling], @subclass.without_states(:first_gear).find(:all)
      end
    end
    
    class MachineWithComplexPluralizationScopesTest < BaseTestCase
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
    
    class MachineWithScopesAndJoinsTest < BaseTestCase
      def setup
        @company = new_model(:company)
        ActiveRecordTest.const_set('Company', @company)
        
        @vehicle = new_model(:vehicle) do
          connection.add_column table_name, :company_id, :integer
          belongs_to :company, :class_name => 'ActiveRecordTest::Company'
        end
        ActiveRecordTest.const_set('Vehicle', @vehicle)
        
        @company_machine = StateMachine::Machine.new(@company, :initial => :active)
        @vehicle_machine = StateMachine::Machine.new(@vehicle, :initial => :parked)
        @vehicle_machine.state :idling
        
        @ford = @company.create
        @mustang = @vehicle.create(:company => @ford)
      end
      
      def test_should_find_records_in_with_scope
        assert_equal [@mustang], @vehicle.with_states(:parked).find(:all, :joins => :company, :conditions => "#{@company.table_name}.state = \"active\"")
      end
      
      def test_should_find_records_in_without_scope
        assert_equal [@mustang], @vehicle.without_states(:idling).find(:all, :joins => :company, :conditions => "#{@company.table_name}.state = \"active\"")
      end
      
      def teardown
        ActiveRecordTest.class_eval do
          remove_const('Vehicle')
          remove_const('Company')
        end
        ActiveSupport::Dependencies.clear if defined?(ActiveSupport::Dependencies)
        super
      end
    end
  else
    $stderr.puts 'Skipping ActiveRecord Scope tests.'
  end
  
  if ActiveRecord.const_defined?(:Relation)
    class MachineWithDefaultScope < BaseTestCase
      def setup
        @model = new_model
        @machine = StateMachine::Machine.new(@model, :initial => :parked)
        @machine.state :idling
        
        @model.class_eval do
          default_scope { with_state(:parked, :idling) }
        end
      end
      
      def test_should_set_initial_state_on_created_object
        object = @model.new
        assert_equal 'parked', object.state
      end
    end
  else
    $stderr.puts 'Skipping ActiveRecord Default Scope tests.'
  end
  
  if Object.const_defined?(:I18n)
    class MachineWithInternationalizationTest < BaseTestCase
      def setup
        I18n.backend = I18n::Backend::Simple.new
        
        # Initialize the backend
        StateMachine::Machine.new(new_model)
        I18n.backend.translate(:en, 'activerecord.errors.messages.invalid_transition', :event => 'ignite', :value => 'idling')
        
        @model = new_model
      end
      
      def test_should_use_defaults
        I18n.backend.store_translations(:en, {
          :activerecord => {:errors => {:messages => {:invalid_transition => "cannot #{interpolation_key('event')}"}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        machine.state :parked, :idling
        machine.event :ignite
        
        record = @model.new(:state => 'idling')
        
        machine.invalidate(record, :state, :invalid_transition, [[:event, 'ignite']])
        assert_equal ['State cannot ignite'], record.errors.full_messages
      end
      
      def test_should_allow_customized_error_key
        I18n.backend.store_translations(:en, {
          :activerecord => {:errors => {:messages => {:bad_transition => "cannot #{interpolation_key('event')}"}}}
        })
        
        machine = StateMachine::Machine.new(@model, :messages => {:invalid_transition => :bad_transition})
        machine.state :parked, :idling
        
        record = @model.new(:state => 'idling')
        
        machine.invalidate(record, :state, :invalid_transition, [[:event, 'ignite']])
        assert_equal ['State cannot ignite'], record.errors.full_messages
      end
      
      def test_should_allow_customized_error_string
        machine = StateMachine::Machine.new(@model, :messages => {:invalid_transition => "cannot #{interpolation_key('event')}"})
        machine.state :parked, :idling
        
        record = @model.new(:state => 'idling')
        
        machine.invalidate(record, :state, :invalid_transition, [[:event, 'ignite']])
        assert_equal ['State cannot ignite'], record.errors.full_messages
      end
      
      def test_should_allow_customized_state_key_scoped_to_class_and_machine
        I18n.backend.store_translations(:en, {
          :activerecord => {:state_machines => {:'active_record_test/foo' => {:state => {:states => {:parked => 'shutdown'}}}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        machine.state :parked
        
        assert_equal 'shutdown', machine.state(:parked).human_name
      end
      
      def test_should_allow_customized_state_key_scoped_to_class
        I18n.backend.store_translations(:en, {
          :activerecord => {:state_machines => {:'active_record_test/foo' => {:states => {:parked => 'shutdown'}}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        machine.state :parked
        
        assert_equal 'shutdown', machine.state(:parked).human_name
      end
      
      def test_should_allow_customized_state_key_scoped_to_machine
        I18n.backend.store_translations(:en, {
          :activerecord => {:state_machines => {:state => {:states => {:parked => 'shutdown'}}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        machine.state :parked
        
        assert_equal 'shutdown', machine.state(:parked).human_name
      end
      
      def test_should_allow_customized_state_key_unscoped
        I18n.backend.store_translations(:en, {
          :activerecord => {:state_machines => {:states => {:parked => 'shutdown'}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        machine.state :parked
        
        assert_equal 'shutdown', machine.state(:parked).human_name
      end
      
      def test_should_support_nil_state_key
        I18n.backend.store_translations(:en, {
          :activerecord => {:state_machines => {:states => {:nil => 'empty'}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        
        assert_equal 'empty', machine.state(nil).human_name
      end
      
      def test_should_allow_customized_event_key_scoped_to_class_and_machine
        I18n.backend.store_translations(:en, {
          :activerecord => {:state_machines => {:'active_record_test/foo' => {:state => {:events => {:park => 'stop'}}}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        machine.event :park
        
        assert_equal 'stop', machine.event(:park).human_name
      end
      
      def test_should_allow_customized_event_key_scoped_to_class
        I18n.backend.store_translations(:en, {
          :activerecord => {:state_machines => {:'active_record_test/foo' => {:events => {:park => 'stop'}}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        machine.event :park
        
        assert_equal 'stop', machine.event(:park).human_name
      end
      
      def test_should_allow_customized_event_key_scoped_to_machine
        I18n.backend.store_translations(:en, {
          :activerecord => {:state_machines => {:state => {:events => {:park => 'stop'}}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        machine.event :park
        
        assert_equal 'stop', machine.event(:park).human_name
      end
      
      def test_should_allow_customized_event_key_unscoped
        I18n.backend.store_translations(:en, {
          :activerecord => {:state_machines => {:events => {:park => 'stop'}}}
        })
        
        machine = StateMachine::Machine.new(@model)
        machine.event :park
        
        assert_equal 'stop', machine.event(:park).human_name
      end
      
      def test_should_only_add_locale_once_in_load_path
        assert_equal 1, I18n.load_path.select {|path| path =~ %r{active_record/locale\.rb$}}.length
        
        # Create another ActiveRecord model that will triger the i18n feature
        new_model
        
        assert_equal 1, I18n.load_path.select {|path| path =~ %r{active_record/locale\.rb$}}.length
      end
      
      def test_should_add_locale_to_beginning_of_load_path
        @original_load_path = I18n.load_path
        I18n.backend = I18n::Backend::Simple.new
        
        app_locale = File.dirname(__FILE__) + '/../../files/en.yml'
        default_locale = File.dirname(__FILE__) + '/../../../lib/state_machine/integrations/active_record/locale.rb'
        I18n.load_path = [app_locale]
        
        StateMachine::Machine.new(@model)
        
        assert_equal [default_locale, app_locale].map {|path| File.expand_path(path)}, I18n.load_path.map {|path| File.expand_path(path)}
      ensure
        I18n.load_path = @original_load_path
      end
      
      def test_should_prefer_other_locales_first
        @original_load_path = I18n.load_path
        I18n.backend = I18n::Backend::Simple.new
        I18n.load_path = [File.dirname(__FILE__) + '/../../files/en.yml']
        
        machine = StateMachine::Machine.new(@model)
        machine.state :parked, :idling
        machine.event :ignite
        
        record = @model.new(:state => 'idling')
        
        machine.invalidate(record, :state, :invalid_transition, [[:event, 'ignite']])
        assert_equal ['State cannot transition'], record.errors.full_messages
      ensure
        I18n.load_path = @original_load_path
      end
      
      private
        def interpolation_key(key)
          !defined?(I18n::VERSION) || I18n::VERSION < '0.4.0' ? "{{#{key}}}" : "%{#{key}}"
        end
    end
  else
    $stderr.puts 'Skipping ActiveRecord I18n tests.'
  end
end
