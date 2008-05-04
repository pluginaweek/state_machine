module PluginAWeek #:nodoc:
  module StateMachine
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
      
      # Runs the actual transition and any actions associated with entering
      # and exiting the states
      def perform(record, *args)
        state = record.send(machine.attribute)
        
        invoke_before_callbacks(state, record) != false &&
        update_state(state, record) &&
        invoke_after_callbacks(state, record) != false
      end
      
      private
        def update_state(from_state, record)
          loopback?(from_state) ? true : record.update_attribute(machine.attribute, to_state)
        end
        
        def invoke_before_callbacks(from_state, record)
          # Start leaving the last state and start entering the next state
          loopback?(from_state) || invoke_callbacks(:before_exit, from_state, record) && invoke_callbacks(:before_enter, to_state, record)
        end
        
        def invoke_after_callbacks(from_state, record)
          # Start leaving the last state and start entering the next state
          loopback?(from_state) || invoke_callbacks(:after_exit, from_state, record) && invoke_callbacks(:after_enter, to_state, record)
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
