module StateMachine
  module Integrations #:nodoc:
    module DataMapper
      version '0.9.x - 0.10.x' do
        def self.active?
          ::DataMapper::VERSION =~ /^0\.\d\./ || ::DataMapper::VERSION =~ /^0\.10\./
        end
        
        def pluralize(word)
          ::Extlib::Inflection.pluralize(word.to_s)
        end
      end
      
      version '0.9.x' do
        def self.active?
          ::DataMapper::VERSION =~ /^0\.9\./
        end
        
        def define_action_helpers
          if action_hook == :save
            define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
              def save(*)
                self.class.state_machines.transitions(self, :save).perform { super }
              end
            end_eval
            
            define_validation_hook
          else
            super
          end
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
        
        def define_action_helpers
          if action_hook == :save
            define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
              def save(*)
                self.class.state_machines.transitions(self, :save).perform { super }
              end
              
              def save!(*)
                self.class.state_machines.transitions(self, :save).perform { super }
              end
              
              def save_self(*)
                self.class.state_machines.transitions(self, :save).perform { super }
              end
            end_eval
            
            define_validation_hook
          else
            super
          end
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
    end
  end
end
