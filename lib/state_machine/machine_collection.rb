module StateMachine
  # Represents a collection of state machines for a class
  class MachineCollection < Hash
    # Initializes the state of each machine in the given object
    def initialize_states(object)
      each do |attribute, machine|
        # Set the initial value of the machine's attribute unless it already
        # exists (which must mean the defaults are being skipped)
        value = machine.read(object)
        machine.write(object, machine.initial_state(object).value) if value.nil? || value.respond_to?(:empty?) && value.empty?
      end
    end
    
    # Runs one or more events in parallel on the given object.  See
    # StateMachine::InstanceMethods#fire_events for more information.
    def fire_events(object, *events)
      run_action = [true, false].include?(events.last) ? events.pop : true
      
      # Generate the transitions to run for each event
      transitions = events.collect do |name|
        # Find the actual event being run
        event = nil
        detect do |attribute, machine|
          event = machine.events[name, :qualified_name]
        end
        
        raise InvalidEvent, "#{name.inspect} is an unknown state machine event" unless event
        
        # Get the transition that will be performed for the event
        unless transition = event.transition_for(object)
          event.machine.invalidate(object, event)
        end
        
        transition
      end.compact
      
      # Run the events in parallel only if valid transitions were found for
      # all of them
      events.length == transitions.length ? Transition.perform(transitions, run_action) : false
    end
  end
end
