module StateMachine
  module Integrations #:nodoc:
    module MongoMapper
      version '0.5.x - 0.6.x' do
        def self.active?
          !defined?(::MongoMapper::Plugins)
        end
        
        def initialize_state?(object, options)
          attributes = options[:attributes] || {}
          super unless attributes.stringify_keys.key?('_id')
        end
        
        def filter_attributes(object, attributes)
          attributes
        end
      end
      
      version '0.5.x - 0.7.x' do
        def self.active?
          !defined?(::MongoMapper::Version) || ::MongoMapper::Version < '0.8.0'
        end
        
        def define_scope(name, scope)
          lambda {|model, values| model.all(scope.call(values))}
        end
      end
      
      version '0.5.x - 0.8.x' do
        def self.active?
          !defined?(::MongoMapper::Version) || ::MongoMapper::Version < '0.9.0'
        end
        
        def define_state_accessor
          owner_class.key(attribute, String) unless owner_class.keys.include?(attribute)
          
          name = self.name
          owner_class.validates_each(attribute, :logic => lambda {|*|
            machine = self.class.state_machine(name)
            machine.invalidate(self, :state, :invalid) unless machine.states.match(self)
          })
        end
      end
    end
  end
end
