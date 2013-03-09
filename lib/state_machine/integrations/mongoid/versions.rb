module StateMachine
  module Integrations #:nodoc:
    module Mongoid
      version '2.x' do
        def self.active?
          ::Mongoid::VERSION =~ /^2\./
        end
        
        def define_state_initializer
          define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
            def initialize(*)
              @attributes ||= {}
              self.class.state_machines.initialize_states(self, :static => :force, :dynamic => false)
              
              super do |*args|
                self.class.state_machines.initialize_states(self, :static => false)
                yield(*args) if block_given?
              end
            end
          end_eval
        end
        
        def owner_class_attribute_default
          attribute_field && attribute_field.default
        end
        
        def define_action_hook
          if action_hook == :save
            define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
              def insert(*)
                self.class.state_machine(#{name.inspect}).send(:around_save, self) { super.persisted? }
                self
              end
              
              def update(*)
                self.class.state_machine(#{name.inspect}).send(:around_save, self) { super }
              end
            end_eval
          else
            super
          end
        end
      end
      
      version '2.0.x - 2.3.x' do
        def self.active?
          ::Mongoid::VERSION =~ /^2\.[0-3]\./
        end
        
        def attribute_field
          owner_class.fields[attribute.to_s]
        end
      end
      
      version '2.0.x - 2.2.x' do
        def self.active?
          ::Mongoid::VERSION =~ /^2\.[0-2]\./
        end
        
        def define_state_initializer
          define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
            # Initializes dynamic states
            def initialize(*)
              super do |*args|
                self.class.state_machines.initialize_states(self, :static => false)
                yield(*args) if block_given?
              end
            end
            
            # Initializes static states
            def apply_default_attributes(*)
              result = super
              self.class.state_machines.initialize_states(self, :static => :force, :dynamic => false, :to => result) if new_record?
              result
            end
          end_eval
        end
      end
    end
  end
end
