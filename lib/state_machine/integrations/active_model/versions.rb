module StateMachine
  module Integrations #:nodoc:
    module ActiveModel
      version '2.x' do
        def self.active?
          !defined?(::ActiveModel::VERSION) || ::ActiveModel::VERSION::MAJOR == 2
        end
        
        def define_validation_hook
          action = self.action
          define_helper(:instance, :valid?) do |machine, object, _super, *|
            object.class.state_machines.transitions(object, action, :after => false).perform { _super.call }
          end
        end
      end
      
      version '3.0.x' do
        def self.active?
          defined?(::ActiveModel::VERSION) && ::ActiveModel::VERSION::MAJOR == 3 && ::ActiveModel::VERSION::MINOR == 0
        end
        
        def define_validation_hook
          # +around+ callbacks don't have direct access to results until AS 3.1
          owner_class.set_callback(:validation, :after, 'value', :prepend => true)
          super
        end
      end
    end
  end
end
