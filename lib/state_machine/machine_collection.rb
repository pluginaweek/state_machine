module StateMachine
  # Represents a collection of state machines for a class
  class MachineCollection < Hash
    # Initializes the state of each machine in the given object.  Initial
    # values are only set if the machine's attribute doesn't already exist
    # (which must mean the defaults are being skipped)
    def initialize_states(object, options = {})
      if ignore = options[:ignore]
        ignore = ignore.map {|attribute| attribute.to_sym}
      end
      
      each_value do |machine|
        if (!ignore || !ignore.include?(machine.attribute)) && (!options.include?(:dynamic) || machine.dynamic_initial_state? == options[:dynamic])
          value = machine.read(object, :state)
          machine.initialize_state(object) if ignore || value.nil? || value.respond_to?(:empty?) && value.empty?
        end
      end
    end
    
    # Runs one or more events in parallel on the given object.  See
    # StateMachine::InstanceMethods#fire_events for more information.
    def fire_events(object, *events)
      run_action = [true, false].include?(events.last) ? events.pop : true
      
      # Generate the transitions to run for each event
      transitions = events.collect do |event_name|
        # Find the actual event being run
        event = nil
        detect {|name, machine| event = machine.events[event_name, :qualified_name]}
        
        raise InvalidEvent, "#{event_name.inspect} is an unknown state machine event" unless event
        
        # Get the transition that will be performed for the event
        unless transition = event.transition_for(object)
          machine = event.machine
          machine.invalidate(object, :state, :invalid_transition, [[:event, event_name]])
        end
        
        transition
      end.compact
      
      # Run the events in parallel only if valid transitions were found for
      # all of them
      if events.length == transitions.length
        TransitionCollection.new(transitions, :actions => run_action).perform
      else
        false
      end
    end
    
    # Builds the collection of transitions for all event attributes defined on
    # the given object.  This will only include events whose machine actions
    # match the one specified.
    # 
    # These should only be fired as a result of the action being run.
    def transitions(object, action, options = {})
      transitions = map do |name, machine|
        machine.events.attribute_transition_for(object, true) if machine.action == action
      end
      
      AttributeTransitionCollection.new(transitions.compact, options)
    end
  end
end
