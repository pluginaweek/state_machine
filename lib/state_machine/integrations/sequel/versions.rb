module StateMachine
  module Integrations #:nodoc:
    module Sequel
      version '2.8.x - 3.13.x' do
        def self.active?
          !defined?(::Sequel::MAJOR) || ::Sequel::MAJOR == 2 || ::Sequel::MAJOR == 3 && ::Sequel::MINOR <= 13
        end
        
        def handle_validation_failure
          'raise_on_save_failure ? save_failure(:validation) : result'
        end
        
        def handle_save_failure
          'save_failure(:save)'
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
        
        def model_from_dataset(dataset)
          dataset.model_classes[nil]
        end
      end
    end
  end
end
