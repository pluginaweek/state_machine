module StateMachine
  # Represents a collection of states in a state machine
  class EventCollection < NodeCollection
    def initialize #:nodoc:
      super(:index => [:name, :qualified_name])
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
      
      if include_no_op && machine = self.machine
        state = machine.states.match(object)
        
        # Add the no-op loopback transition unless a loopback is already included
        unless transitions.any? {|transition| transition.to_name == state.name}
          transitions.unshift(Transition.new(object, machine, nil, state.name, state.name))
        end
      end
      
      transitions
    end
  end
end
