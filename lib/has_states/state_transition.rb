module PluginAWeek #:nodoc:
  module Has #:nodoc:
    module States
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
          @loopback = from_state == to_state
          @guards = Array(options[:if])
        end
        
        # Whether or not this is a loopback transition (i.e. the from state is
        # the same as the to state)
        def loopback?
          @loopback == true
        end
        
        # Ensures that the transition can occur by checking the guards
        # associated with it
        def can_perform_on?(record, *args)
          @guards.all? {|guard| record.eval_call(guard, *args)}
        end
        
        # Runs the actual transition and any actions associated with entering
        # and exiting the states
        def perform(event, record, *args)
          if can_perform_on?(record, *args) && invoke_before_callbacks(record) && (!record.respond_to?(event.name) || record.send(event.name, *args) != false)
            # Update the state and 
            record.update_attributes!(:state_id => to_state.record.id)
            record.instance_variable_set('@state', nil) if !loopback? # Unload the association
            record.send(:record_state_change, event, from_state, to_state)
            
            result = invoke_after_callbacks(record)
          end
          
          result || false
        end
        
        def hash #:nodoc:
          "#{@from_state.name}-#{@to_state.name}".hash
        end
        
        def ==(obj) #:nodoc:
          @from_state == obj.from_state && @to_state == obj.to_state
        end
        alias :eql? :==
        
        private
        def invoke_before_callbacks(record) #:nodoc:
          # Start leaving the last state and start entering the next state
          loopback? || record.send(:callback, "before_exit_#{from_state.name}") != false && record.send(:callback, "before_enter_#{to_state.name}") != false
        end
        
        def invoke_after_callbacks(record) #:nodoc:
          # Start leaving the last state and start entering the next state
          loopback? || record.send(:callback, "after_exit_#{from_state.name}") != false && record.send(:callback, "after_enter_#{to_state.name}") != false
        end
      end
    end
  end
end
