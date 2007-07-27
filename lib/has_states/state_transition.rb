module PluginAWeek #:nodoc:
  module Has #:nodoc:
    module States #:nodoc:
      # A transition indicates a state change and is described by a condition
      # that would need to be fulfilled to enable the transition.  Transitions
      # consist of:
      # * The starting state
      # * The ending state
      # * A guard to check if the transition is allowed
      class StateTransition
        attr_reader :from_state, :to_state
        
        def initialize(from_state, to_state, options) #:nodoc:
          options.symbolize_keys!.assert_valid_keys(:if)
          
          @from_state, @to_state = from_state, to_state
          @guards = Array(options[:if])
        end
        
        # Ensures that the transition can occur by checking the guards
        # associated with it
        def can_perform_on?(record, *args)
          @guards.all? {|guard| record.eval_call(guard, *args)}
        end
        
        # Runs the actual transition and any actions associated with entering
        # and exiting the states
        def perform(record, *args)
          return false unless can_perform_on?(record, *args)
          
          loopback = from_state == to_state
          
          unless loopback
            # Start leaving the last state
            record.send(:callback, "before_exit_#{from_state.name}")
            
            # Start entering the next state
            record.send(:callback, "before_enter_#{to_state.name}")
          end
          
          record.update_attributes!(:state_id => to_state.record.id)
          record.instance_variable_set('@state', nil) if !loopback # Unload the association
          
          unless loopback
            # Leave the last state
            record.send(:callback, "after_exit_#{from_state.name}")
            
            # Enter the next state
            record.send(:callback, "after_enter_#{to_state.name}")
          end
          
          true
        end
        
        def hash #:nodoc:
          "#{@from_state.name}-#{@to_state.name}".hash
        end
        
        def ==(obj) #:nodoc:
          @from_state == obj.from_state && @to_state == obj.to_state
        end
        alias :eql? :==
      end
    end
  end
end