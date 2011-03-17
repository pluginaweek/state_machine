module StateMachine
  module Integrations #:nodoc:
    module DataMapper
      version '0.9.x' do
        def self.active?
          ::DataMapper::VERSION =~ /^0\.9\./
        end
        
        def action_hook
          action
        end
        
        def mark_dirty(object, value)
          object.original_values[self.attribute] = "#{value}-ignored" if object.original_values[self.attribute] == value
        end
      end
      
      version '0.9.x - 0.10.x' do
        def self.active?
          ::DataMapper::VERSION =~ /^0\.\d\./ || ::DataMapper::VERSION =~ /^0\.10\./
        end
        
        def pluralize(word)
          ::Extlib::Inflection.pluralize(word.to_s)
        end
      end
      
      version '1.0.0' do
        def self.active?
          ::DataMapper::VERSION == '1.0.0'
        end
        
        def pluralize(word)
          (defined?(::ActiveSupport::Inflector) ? ::ActiveSupport::Inflector : ::Extlib::Inflection).pluralize(word.to_s)
        end
      end
      
      version '0.9.4 - 0.9.6' do
        def self.active?
          ::DataMapper::VERSION =~ /^0\.9\.[4-6]/
        end
        
        # 0.9.4 - 0.9.6 fails to run after callbacks when validations are
        # enabled because of the way dm-validations integrates
        def define_action_helpers?
          super if action != :save || !supports_validations?
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
