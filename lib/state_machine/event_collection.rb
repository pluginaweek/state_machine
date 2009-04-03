module StateMachine
  # Represents a collection of states in a state machine
  class EventCollection < NodeCollection
    def initialize(machine) #:nodoc:
      super(machine, :index => [:name, :qualified_name])
    end
    
    # Gets the list of events that can be fired on the given object.
    # 
    # == Examples
    # 
    #   class Vehicle
    #     state_machine :initial => :parked do
    #       event :park do
    #         transition :idling => :parked
    #       end
    #       
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #   end
    #   
    #   events = Vehicle.state_machine(:state).events
    #   
    #   vehicle = Vehicle.new               # => #<Vehicle:0xb7c464b0 @state="parked">
    #   events.valid_for(vehicle)           # => [#<StateMachine::Event name=:ignite transitions=[:parked => :idling]>]
    #   
    #   vehicle.state = 'idling'
    #   events.valid_for(vehicle)           # => [#<StateMachine::Event name=:park transitions=[:idling => :parked]>]
    def valid_for(object)
      select {|event| event.can_fire?(object)}
    end
    
    # Gets the list of transitions that can be run on the given object.  This
    # can also always include a no-op loopback transition in cases where the
    # states that can be transitioned to is being given as a list of options.
    # 
    # == Examples
    # 
    #   class Vehicle
    #     state_machine :initial => :parked do
    #       event :park do
    #         transition :idling => :parked
    #       end
    #       
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #   end
    #   
    #   events = Vehicle.state_machine.events
    #   
    #   vehicle = Vehicle.new                   # => #<Vehicle:0xb7c464b0 @state="parked">
    #   events.transitions_for(vehicle)         # => [#<StateMachine::Transition attribute=:state event=:ignite from="parked" from_name=:parked to="idling" to_name=:idling>]
    #   
    #   vehicle.state = 'idling'
    #   events.transitions_for(vehicle)         # => [#<StateMachine::Transition attribute=:state event=:park from="idling" from_name=:idling to="parked" to_name=:parked>]
    #   
    #   # Always include a loopback
    #   events.transitions_for(vehicle, true)   #=> [#<StateMachine::Transition attribute=:state event=nil from="idling" from_name=:idling to="idling" to_name=:idling>,
    #                                                #<StateMachine::Transition attribute=:state event=:park from="idling" from_name=:idling to="parked" to_name=:parked>]
    def transitions_for(object, include_no_op = false)
      # Get the possible transitions for this object
      transitions = collect {|event| event.transition_for(object)}.compact
      
      if include_no_op
        state = machine.states.match(object)
        
        # Add the no-op loopback transition unless a loopback is already included
        unless transitions.any? {|transition| transition.to_name == state.name}
          transitions.unshift(Transition.new(object, machine, nil, state.name, state.name))
        end
      end
      
      transitions
    end
    
    # Gets the transition that should be performed for the event stored in the
    # given object's event attribute.  This also takes an additional parameter
    # for automatically invalidating the object if the event or transition
    # are invalid.  By default, this is turned off.
    # 
    # *Note* that if a transition has already been generated for the event,
    # then that transition will be used.
    # 
    # == Examples
    # 
    #   class Vehicle < ActiveRecord::Base
    #     state_machine :initial => :parked do
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new                       # => #<Vehicle id: nil, state: "parked">
    #   events = Vehicle.state_machine.events
    #   
    #   vehicle.state_event = nil
    #   events.attribute_transition_for(vehicle)    # => nil # Event isn't defined
    #   
    #   vehicle.state_event = 'invalid'
    #   events.attribute_transition_for(vehicle)    # => false # Event is invalid
    #   
    #   vehicle.state_event = 'ignite'
    #   events.attribute_transition_for(vehicle)    # => #<StateMachine::Transition attribute=:state event=:ignite from="parked" from_name=:parked to="idling" to_name=:idling>
    def attribute_transition_for(object, invalidate = false)
      return unless machine.action
      
      result = nil
      attribute = machine.attribute
      
      if name = object.send("#{attribute}_event")
        if event = self[name.to_sym, :qualified_name]
          unless result = object.send("#{attribute}_event_transition") || event.transition_for(object)
            # No valid transition: invalidate
            machine.invalidate(object, "#{attribute}_event", :invalid_event, [[:state, machine.states.match(object).name]]) if invalidate
            result = false
          end
        else
          # Event is unknown: invalidate
          machine.invalidate(object, "#{attribute}_event", :invalid) if invalidate
          result = false
        end
      end
      
      result
    end
  end
end
