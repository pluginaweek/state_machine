module StateMachine
  module Integrations
    # Provides a set of base helpers for managing individual integrations
    module Base
      # Never matches
      def self.matches?(klass)
        false
      end
      
      def self.included(base) #:nodoc:
        base.class_eval do
          extend ClassMethods
        end
      end
      
      module ClassMethods
        # Tracks the various version overrides for an integration
        def versions
          @versions ||= []
        end
        
        # Creates a new version override for an integration.  When this
        # integration is activated, each version that is marked as active will
        # also extend the integration.
        # 
        # == Example
        # 
        #   module StateMachine
        #     module Integrations
        #       module ORMLibrary
        #         version '0.2.x - 0.3.x' do
        #           def self.active?
        #             ::ORMLibrary::VERSION >= '0.2.0' && ::ORMLibrary::VERSION < '0.4.0'
        #           end
        #           
        #           def invalidate(object, attribute, message, values = [])
        #             # Override here...
        #           end
        #         end
        #       end
        #     end
        #   end
        # 
        # In the above example, a version override is defined for the ORMLibrary
        # integration when the version is between 0.2.x and 0.3.x.
        def version(name, &block)
          versions << mod = Module.new(&block)
          mod
        end
        
        # Extends the given object with any version overrides that are currently
        # active
        def extended(base)
          versions.each do |version|
             base.extend(version) if version.active?
          end
        end
      end
    end
  end
end
