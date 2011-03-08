module StateMachine
  module Integrations #:nodoc:
    module Sequel
      version '2.8.x - 3.13.x' do
        def self.active?
          !defined?(::Sequel::MAJOR) || ::Sequel::MAJOR == 2 || ::Sequel::MAJOR == 3 && ::Sequel::MINOR <= 13
        end
        
        def handle_validation_failure
          lambda do |object, args, yielded, result|
            object.instance_eval do
              raise_on_save_failure ? save_failure(:validation) : result
            end
          end
        end
        
        def handle_save_failure
          lambda do |object|
            object.instance_eval do
              save_failure(:save)
            end
          end
        end
      end
      
      version '2.8.x - 2.11.x' do
        def self.active?
          !defined?(::Sequel::MAJOR) || ::Sequel::MAJOR == 2 && ::Sequel::MINOR <= 11
        end
        
        def load_inflector
        end
        
        def action_hook
          action == :save ? :save : super
        end
      end
    end
  end
end
