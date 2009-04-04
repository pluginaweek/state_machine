module StateMachine
  # Represents a collection of events in a state machine
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
    
    # Gets the list of transitions that can be run on the given object.
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
    def transitions_for(object)
      map {|event| event.transition_for(object)}.compact
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
