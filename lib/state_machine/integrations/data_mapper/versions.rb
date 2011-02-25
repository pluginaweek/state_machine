module StateMachine
  module Integrations #:nodoc:
    module DataMapper
      version '0.9.x' do
        def self.active?
          ::DataMapper::VERSION =~ /^0\.9\./
        end
        
        def mark_dirty(object, value)
          object.original_values[self.attribute] = "#{value}-ignored" if object.original_values[self.attribute] == value
        end
      end
      
      version '0.9.x - 0.10.x' do
        def self.active?
          ::DataMapper::VERSION =~ /^0\.\d\./
        end
        
        def save_hook
          :save
        end
      end
      
      version '0.9.4 - 0.9.6' do
        def self.active?
          ::DataMapper::VERSION =~ /^0\.9\.[4-6]/
        end
        
        # 0.9.4 - 0.9.6 fails to run after callbacks when validations are
        # enabled because of the way dm-validations integrates
        def define_action_helpers
          super unless supports_validations?
        end
      end
      
      version '0.10.x' do
        def self.active?
          ::DataMapper::VERSION =~ /^0\.10\./
        end
        
        def mark_dirty(object, value)
          property = owner_class.properties[self.attribute]
          object.original_attributes[property] = "#{value}-ignored" unless object.original_attributes.include?(property)
        end
      end
    end
  end
end
