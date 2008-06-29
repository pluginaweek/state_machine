module PluginAWeek #:nodoc:
  module StateMachine
    # An invalid transition was attempted
    class InvalidTransition < StandardError
    end
    
    # A transition indicates a state change and is described by a condition
    # that would need to be fulfilled to enable the transition.  Transitions
    # consist of:
    # * The starting state
    # * The ending state
    # * A guard to check if the transition is allowed
    class Transition
      # The state from which the transition is being made
      attr_reader :from_state
      
      # The state to which the transition is being made
      attr_reader :to_state
      
      # The event that caused the transition
      attr_reader :event
      
      delegate  :machine,
                  :to => :event
      
      def initialize(event, from_state, to_state) #:nodoc:
        @event = event
        @from_state = from_state
        @to_state = to_state
        @loopback = from_state == to_state
      end
      
      # Whether or not this is a loopback transition (i.e. from and to state are the same)
      def loopback?(state = from_state)
        state == to_state
      end
      
      # Determines whether or not this transition can be performed on the given
      # states
      def can_perform_on?(record)
        !from_state || from_state == record.send(machine.attribute)
      end
      
      # Runs the actual transition and any callbacks associated with entering
      # and exiting the states
      def perform(record, *args)
        perform_with_optional_bang(record, false, *args)
      end
      
      # Runs the actual transition and any callbacks associated with entering
      # and exiting the states. Any errors during validation or saving will be
      # raised.
      def perform!(record, *args)
        perform_with_optional_bang(record, true, *args) || raise(PluginAWeek::StateMachine::InvalidTransition)
      end
      
      private
        # Performs the transition
        def perform_with_optional_bang(record, bang, *args)
          state = record.send(machine.attribute)
          
          return false if invoke_before_callbacks(state, record) == false
          result = update_state(state, bang, record)
          invoke_after_callbacks(state, record)
          result
        end
        
        # Updates the record's attribute to the state represented by this transition
        def update_state(from_state, bang, record)
          if loopback?(from_state)
            true
          else
            record.send("#{machine.attribute}=", to_state)
            bang ? record.save! : record.save
          end
        end
        
        def invoke_before_callbacks(from_state, record)
          # Start leaving the last state and start entering the next state
          loopback?(from_state) || invoke_callbacks(:before_exit, from_state, record) && invoke_callbacks(:before_enter, to_state, record)
        end
        
        def invoke_after_callbacks(from_state, record)
          # Start leaving the last state and start entering the next state
          unless loopback?(from_state)
            invoke_callbacks(:after_exit, from_state, record)
            invoke_callbacks(:after_enter, to_state, record)
          end
          
          true
        end
        
        def invoke_callbacks(type, state, record)
          kind = "#{type}_#{machine.attribute}_#{state}"
          if record.class.respond_to?("#{kind}_callback_chain")
            record.run_callbacks(kind) {|result, record| result == false}
          else
            true
          end
        end
    end
  end
end
