module StateMachine
  module Integrations #:nodoc:
    module ActiveModel
      # Adds support for invoking callbacks on ActiveModel observers with more
      # than one argument (e.g. the record *and* the state transition).  By
      # default, ActiveModel only supports passing the record into the
      # callbacks.
      # 
      # For example:
      # 
      #   class VehicleObserver < ActiveModel::Observer
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
        def update_with_transition(args)
          observed_method, object, transition = args
          return unless respond_to?(observed_method)
          return if disabled_for?(object)

          send(observed_method, object, transition)
        end
      end
    end
  end
end

ActiveModel::Observer.class_eval do
  include StateMachine::Integrations::ActiveModel::Observer
end if defined?(ActiveModel::Observer)
