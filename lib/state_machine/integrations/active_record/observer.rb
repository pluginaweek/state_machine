module StateMachine
  module Integrations #:nodoc:
    module ActiveRecord
      # Adds support for invoking callbacks on ActiveRecord observers with more
      # than one argument (e.g. the record *and* the state transition).  By
      # default, ActiveRecord only supports passing the record into the
      # callbacks.
      # 
      # For example:
      # 
      #   class VehicleObserver < ActiveRecord::Observer
      #     # The default behavior: only pass in the record
      #     def after_save(vehicle)
      #     end
      #     
      #     # Custom behavior: allow the transition to be passed in as well
      #     def after_transition(vehicle, transition)
      #       Audit.log(vehicle, transition)
      #     end
      #   end
      module Observer
        def self.included(base) #:nodoc:
          base.class_eval do
            alias_method :update_without_multiple_args, :update
            alias_method :update, :update_with_multiple_args
          end
        end
        
        # Allows additional arguments other than the object to be passed to the
        # observed methods
        def update_with_multiple_args(observed_method, object, *args) #:nodoc:
          send(observed_method, object, *args) if respond_to?(observed_method)
        end
      end
    end
  end
end

ActiveRecord::Observer.class_eval do
  include StateMachine::Integrations::ActiveRecord::Observer
end
