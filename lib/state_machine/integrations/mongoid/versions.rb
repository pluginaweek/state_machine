module StateMachine
  module Integrations #:nodoc:
    module Mongoid
      # Assumes Mongoid 2.2+ uses ActiveModel 3.1+
      version '2.0.x - 2.1.x' do
        def self.active?
          ::Mongoid::VERSION >= '2.0.0' && ::Mongoid::VERSION < '2.2.0'
        end
        
        def define_action_hook
          # +around+ callbacks don't have direct access to results until AS 3.1
          owner_class.set_callback(:save, :after, 'value', :prepend => true) if action_hook == :save
          super
        end
      end
      
      version '2.0.x' do
        def self.active?
          ::Mongoid::VERSION >= '2.0.0' && ::Mongoid::VERSION < '2.1.0'
        end
        
        # Forces the change in state to be recognized regardless of whether the
        # state value actually changed
        def write(object, attribute, value, *args)
          result = super
          
          if (attribute == :state || attribute == :event && value) && !object.send("#{self.attribute}_changed?")
            current = read(object, :state)
            object.changes[self.attribute.to_s] = [attribute == :event ? current : value, current]
          end
          
          result
        end
        
        protected
          # Mongoid uses its own implementation of dirty tracking instead of
          # ActiveModel's and doesn't support the #{attribute}_will_change! APIs
          def supports_dirty_tracking?(object)
            false
          end
      end
    end
  end
end
