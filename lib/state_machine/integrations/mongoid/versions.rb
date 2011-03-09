module StateMachine
  module Integrations #:nodoc:
    module Mongoid
      # Assumes Mongoid 2.1+ uses ActiveModel 3.1+
      version '2.0.x' do
        def self.active?
          ::Mongoid::VERSION >= '2.0.0' && ::Mongoid::VERSION < '2.1.0'
        end
        
        def define_action_hook
          # +around+ callbacks don't have direct access to results until AS 3.1
          owner_class.set_callback(:save, :after, 'value', :prepend => true) if action_hook == :save
          super
        end
      end
    end
  end
end
