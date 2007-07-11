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
        attr_reader :from_name,
                    :to_name,
                    :options
        
        def initialize(from_name, to_name, options) #:nodoc:
          options.symbolize_keys!.assert_valid_keys(:if)
          
          @from_name, @to_name = from_name.to_sym, to_name.to_sym
          @guards = Array(options[:if])
        end
        
        # Runs the actual transition and any actions associated with entering
        # and exiting the states
        def perform(record, *args)
          return false unless guard(record, *args)
          
          loopback = record.state_name == to_name
          
          next_state = record.class.valid_states[to_name]
          last_state = record.class.valid_states[record.state_name]
          
          # Start leaving the last state
          last_state.before_exit(record, *args) unless loopback
          
          # Start entering the next state
          next_state.before_enter(record, *args) unless loopback
          
          record.state = next_state.record
          
          # Leave the last state
          last_state.after_exit(record, *args) unless loopback
          
          # Enter the next state
          next_state.after_enter(record, *args) unless loopback
          
          true
        end
        
        def ==(obj) #:nodoc:
          @from_name == obj.from_name && @to_name == obj.to_name
        end
        
        private
        # Ensures that the transition can occur by checking the guards
        # associated with it
        def guard(record, *args)
          @guards.all? {|guard| record.eval_call(guard, *args)}
        end
      end
    end
  end
end