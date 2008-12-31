require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

begin
  # Load library
  require 'rubygems'
  require 'dm-core'
  
  # Establish database connection
  DataMapper.setup(:default, 'sqlite3::memory:')
  DataObjects::Sqlite3.logger = DataObjects::Logger.new("#{File.dirname(__FILE__)}/../../data_mapper.log", :info)
  
  module DataMapperTest
    class BaseTestCase < Test::Unit::TestCase
      def default_test
      end
      
      protected
        # Creates a new DataMapper resource (and the associated table)
        def new_resource(auto_migrate = true, &block)
          resource = Class.new do
            include DataMapper::Resource
            
            storage_names[:default] = 'foo'
            def self.name; 'DataMapperTest::Foo'; end
            
            property :id, Integer, :serial => true
            property :state, String
            
            auto_migrate! if auto_migrate
          end
          resource.class_eval(&block) if block_given?
          resource
        end
        
        # Creates a new DataMapper observer
        def new_observer(resource, &block)
          observer = Class.new do
            include DataMapper::Observer
          end
          observer.observe(resource)
          observer.class_eval(&block) if block_given?
          observer
        end
    end
    
    class IntegrationTest < BaseTestCase
      def test_should_match_if_class_inherits_from_active_record
        assert StateMachine::Integrations::DataMapper.matches?(new_resource)
      end
      
      def test_should_not_match_if_class_does_not_inherit_from_active_record
        assert !StateMachine::Integrations::DataMapper.matches?(Class.new)
      end
    end
    
    class MachineByDefaultTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource)
      end
      
      def test_should_use_save_as_action
        assert_equal :save, @machine.action
      end
    end
    
    class MachineTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource)
      end
      
      def test_should_create_singular_with_scope
        assert @resource.respond_to?(:with_state)
      end
      
      def test_should_only_include_records_with_state_in_singular_with_scope
        off = @resource.create :state => 'off'
        on = @resource.create :state => 'on'
        
        assert_equal [off], @resource.with_state('off')
      end
      
      def test_should_create_plural_with_scope
        assert @resource.respond_to?(:with_states)
      end
      
      def test_should_only_include_records_with_states_in_plural_with_scope
        off = @resource.create :state => 'off'
        on = @resource.create :state => 'on'
        
        assert_equal [off, on], @resource.with_states('off', 'on')
      end
      
      def test_should_create_singular_without_scope
        assert @resource.respond_to?(:without_state)
      end
      
      def test_should_only_include_records_without_state_in_singular_without_scope
        off = @resource.create :state => 'off'
        on = @resource.create :state => 'on'
        
        assert_equal [off], @resource.without_state('on')
      end
      
      def test_should_create_plural_without_scope
        assert @resource.respond_to?(:without_states)
      end
      
      def test_should_only_include_records_without_states_in_plural_without_scope
        off = @resource.create :state => 'off'
        on = @resource.create :state => 'on'
        error = @resource.create :state => 'error'
        
        assert_equal [off, on], @resource.without_states('error')
      end
      
      def test_should_rollback_transaction_if_false
        @machine.within_transaction(@resource.new) do
          @resource.create
          false
        end
        
        assert_equal 0, @resource.all.size
      end
      
      def test_should_not_rollback_transaction_if_true
        @machine.within_transaction(@resource.new) do
          @resource.create
          true
        end
        
        assert_equal 1, @resource.all.size
      end
      
      def test_should_not_override_the_column_reader
        record = @resource.new
        record.attribute_set(:state, 'off')
        assert_equal 'off', record.state
      end
      
      def test_should_not_override_the_column_writer
        record = @resource.new
        record.state = 'off'
        assert_equal 'off', record.attribute_get(:state)
      end
    end
    
    class MachineUnmigratedTest < BaseTestCase
      def setup
        @resource = new_resource(false)
      end
      
      def test_should_allow_machine_creation
        assert_nothing_raised { StateMachine::Machine.new(@resource) }
      end
    end
    
    class MachineWithInitialStateTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource, :initial => 'off')
        @record = @resource.new
      end
      
      def test_should_set_initial_state_on_created_object
        assert_equal 'off', @record.state
      end
    end
    
    class MachineWithNonColumnStateAttributeTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource, :status, :initial => 'off')
        @record = @resource.new
      end
      
      def test_should_define_a_reader_attribute_for_the_attribute
        assert @record.respond_to?(:status)
      end
      
      def test_should_define_a_writer_attribute_for_the_attribute
        assert @record.respond_to?(:status=)
      end
      
      def test_should_set_initial_state_on_created_object
        assert_equal 'off', @record.status
      end
    end
    
    class MachineWithCallbacksTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource)
        @record = @resource.new(:state => 'off')
        @transition = StateMachine::Transition.new(@record, @machine, 'turn_on', 'off', 'on')
      end
      
      def test_should_run_before_callbacks
        called = false
        @machine.before_transition(lambda {called = true})
        
        @transition.perform
        assert called
      end
      
      def test_should_pass_transition_into_before_callbacks_with_one_argument
        transition = nil
        @machine.before_transition(lambda {|arg| transition = arg})
        
        @transition.perform
        assert_equal @transition, transition
      end
      
      def test_should_pass_transition_into_before_callbacks_with_multiple_arguments
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
      
      def test_should_pass_transition_and_result_into_after_callbacks_with_multiple_arguments
        callback_args = nil
        @machine.after_transition(lambda {|*args| callback_args = args})
        
        @transition.perform
        assert_equal [@transition, true], callback_args
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
        klass.send(:define_method, :after_turn_on) do |*args|
          callback_args = args
        end
        
        @machine.before_transition(:after_turn_on)
        
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
    
    begin
      require 'dm-observer'
      
      class MachineWithObserversTest < BaseTestCase
        def setup
          @resource = new_resource
          @machine = StateMachine::Machine.new(@resource)
          @record = @resource.new(:state => 'off')
          @transition = StateMachine::Transition.new(@record, @machine, 'turn_on', 'off', 'on')
        end
        
        def test_should_call_before_transition_callback_if_requirements_match
          called = false
          
          observer = new_observer(@resource) do
            before_transition :from => 'off' do
              called = true
            end
          end
          
          @transition.perform
          assert called
        end
        
        def test_should_not_call_before_transition_callback_if_requirements_do_not_match
          called = false
          
          observer = new_observer(@resource) do
            before_transition :from => 'on' do
              called = true
            end
          end
          
          @transition.perform
          assert !called
        end
        
        def test_should_allow_targeting_specific_machine
          @second_machine = StateMachine::Machine.new(@resource, :status)
          
          called_state = false
          called_status = false
          
          observer = new_observer(@resource) do
            before_transition :state, :from => 'off' do
              called_state = true
            end
            
            before_transition :status, :from => 'off' do
              called_status = true
            end
          end
          
          @transition.perform
          
          assert called_state
          assert !called_status
        end
        
        def test_should_pass_transition_to_before_callbacks
          callback_args = nil
          
          observer = new_observer(@resource) do
            before_transition do |*args|
              callback_args = args
            end
          end
          
          @transition.perform
          assert_equal [@transition], callback_args
        end
        
        def test_should_call_after_transition_callback_if_requirements_match
          called = false
          
          observer = new_observer(@resource) do
            after_transition :from => 'off' do
              called = true
            end
          end
          
          @transition.perform
          assert called
        end
        
        def test_should_not_call_after_transition_callback_if_requirements_do_not_match
          called = false
          
          observer = new_observer(@resource) do
            after_transition :from => 'on' do
              called = true
            end
          end
          
          @transition.perform
          assert !called
        end
        
        def test_should_pass_transition_and_result_to_before_callbacks
          callback_args = nil
          
          observer = new_observer(@resource) do
            after_transition do |*args|
              callback_args = args
            end
          end
          
          @transition.perform
          assert_equal [@transition, true], callback_args
        end
      end
      
      class MachineWithMixedCallbacksTest < BaseTestCase
        def setup
          @resource = new_resource
          @machine = StateMachine::Machine.new(@resource)
          @record = @resource.new(:state => 'off')
          @transition = StateMachine::Transition.new(@record, @machine, 'turn_on', 'off', 'on')
          
          @notifications = notifications = []
          
          # Create callbacks
          @machine.before_transition(lambda {notifications << :callback_before_transition})
          @machine.after_transition(lambda {notifications << :callback_after_transition})
          
          observer = new_observer(@resource) do
            before_transition do
              notifications << :observer_before_transition
            end
            
            after_transition do
              notifications << :observer_after_transition
            end
          end
          
          @transition.perform
        end
        
        def test_should_invoke_callbacks_in_specific_order
          expected = [
            :callback_before_transition,
            :observer_before_transition,
            :callback_after_transition,
            :observer_after_transition
          ]
          
          assert_equal expected, @notifications
        end
      end
    rescue LoadError
      $stderr.puts 'Skipping DataMapper Observer tests. `gem install dm-observer` and try again.'
    end
  end
rescue LoadError
  $stderr.puts 'Skipping DataMapper tests. `gem install dm-core rspec hoe launchy do_sqlite3` and try again.'
end
