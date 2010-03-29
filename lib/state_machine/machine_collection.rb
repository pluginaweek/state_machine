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
    
    # Runs one or more event attributes in parallel during the invocation of
    # an action on the given object.  after_transition callbacks can be
    # optionally disabled if the events are being only partially fired (for
    # example, when validating records in ORM integrations).
    # 
    # The event attributes that will be fired are based on which machines
    # match the action that is being invoked.
    # 
    # == Examples
    # 
    #   class Vehicle
    #     include DataMapper::Resource
    #     property :id, Serial
    #     
    #     state_machine :initial => :parked do
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #     
    #     state_machine :alarm_state, :namespace => 'alarm', :initial => :active do
    #       event :disable do
    #         transition all => :off
    #       end
    #     end
    #   end
    # 
    # With valid events:
    # 
    #   vehicle = Vehicle.create                      # => #<Vehicle id=1 state="parked" alarm_state="active">
    #   vehicle.state_event = 'ignite'
    #   vehicle.alarm_state_event = 'disable'
    #   
    #   Vehicle.state_machines.fire_event_attributes(vehicle, :save) { true }
    #   vehicle.state                                 # => "idling"
    #   vehicle.state_event                           # => nil
    #   vehicle.alarm_state                           # => "off"
    #   vehicle.alarm_state_event                     # => nil
    # 
    # With invalid events:
    #   
    #   vehicle = Vehicle.create                      # => #<Vehicle id=1 state="parked" alarm_state="active">
    #   vehicle.state_event = 'park'
    #   vehicle.alarm_state_event = 'disable'
    #   
    #   Vehicle.state_machines.fire_event_attributes(vehicle, :save) { true }
    #   vehicle.state                                 # => "parked"
    #   vehicle.state_event                           # => nil
    #   vehicle.alarm_state                           # => "active"
    #   vehicle.alarm_state_event                     # => nil
    #   vehicle.errors                                # => #<DataMapper::Validate::ValidationErrors:0xb7af9abc @errors={"state_event"=>["is invalid"]}>
    # 
    # With partial firing:
    # 
    #   vehicle = Vehicle.create                      # => #<Vehicle id=1 state="parked" alarm_state="active">
    #   vehicle.state_event = 'ignite'
    #   
    #   Vehicle.state_machines.fire_event_attributes(vehicle, :save, false) { true }
    #   vehicle.state                                 # => "idling"
    #   vehicle.state_event                           # => "ignite"
    #   vehicle.state_event_transition                # => #<StateMachine::Transition attribute=:state event=:ignite from="parked" from_name=:parked to="idling" to_name=:idling>
    def fire_event_attributes(object, action, complete = true)
      # Get the transitions to fire for each applicable machine
      transitions = map {|name, machine| machine.action == action ? machine.events.attribute_transition_for(object, true) : nil}.compact
      return yield if transitions.empty?
      
      # Make sure all events were valid
      if transitions.all?
        collection = AttributeTransitionCollection.new(transitions, :after => complete, :transaction => false)
        success = collection.perform { yield }
        collection.results.include?(action) ? collection.results[action] : success
      else
        false
      end
    end
  end
end
