module StateMachine
  module Integrations #:nodoc:
    module Sequel
      version '2.8.x - 3.23.x' do
        def self.active?
          !defined?(::Sequel::MAJOR) || ::Sequel::MAJOR == 2 || ::Sequel::MAJOR == 3 && ::Sequel::MINOR <= 23
        end
        
        def define_state_initializer
          define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
            def initialize(*)
              super do |*args|
                self.class.state_machines.initialize_states(self, :static => false)
                changed_columns.clear
                yield(*args) if block_given?
              end
            end
            
            def set(*)
              self.class.state_machines.initialize_states(self, :static => :force, :dynamic => false) if values.empty?
              super
            end
          end_eval
        end
        
        def define_validation_hook
          define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
            def valid?(*args)
              opts = args.first.is_a?(Hash) ? args.first : {}
              yielded = false
              result = self.class.state_machines.transitions(self, :save, :after => false).perform do
                yielded = true
                super
              end
              
              if yielded || result
                result
              else
                #{handle_validation_failure}
              end
            end
          end_eval
        end
      end
      
      version '2.8.x - 3.13.x' do
        def self.active?
          !defined?(::Sequel::MAJOR) || ::Sequel::MAJOR == 2 || ::Sequel::MAJOR == 3 && ::Sequel::MINOR <= 13
        end
        
        def handle_validation_failure
          'raise_on_save_failure ? save_failure(:validation) : result'
        end
        
        def handle_save_failure
          'save_failure(:save) if raise_on_save_failure'
        end
      end
      
      version '2.8.x - 2.11.x' do
        def self.active?
          !defined?(::Sequel::MAJOR) || ::Sequel::MAJOR == 2 && ::Sequel::MINOR <= 11
        end
        
        def load_plugins
        end
        
        def load_inflector
        end
        
        def model_from_dataset(dataset)
          dataset.model_classes[nil]
        end
        
        def define_state_accessor
          name = self.name
          owner_class.validates_each(attribute) do |record, attr, value|
            machine = record.class.state_machine(name)
            machine.invalidate(record, :state, :invalid) unless machine.states.match(record)
          end
        end
      end
      
      version '3.14.x - 3.23.x' do
        def self.active?
          defined?(::Sequel::MAJOR) && ::Sequel::MAJOR == 3 && ::Sequel::MINOR >= 14 && ::Sequel::MINOR <= 23
        end
        
        def handle_validation_failure
          'raise_on_failure?(opts) ? raise_hook_failure(:validation) : result'
        end
      end
    end
  end
end
