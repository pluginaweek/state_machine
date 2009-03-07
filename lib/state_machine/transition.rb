module StateMachine
  # An invalid transition was attempted
  class InvalidTransition < StandardError
  end
  
  # A transition represents a state change for a specific attribute.
  # 
  # Transitions consist of:
  # * An event
  # * A starting state
  # * An ending state
  class Transition
    # The object being transitioned
    attr_reader :object
    
    # The state machine for which this transition is defined
    attr_reader :machine
    
    # The event that triggered the transition
    attr_reader :event
    
    # The original state value *before* the transition
    attr_reader :from
    
    # The original state name *before* the transition
    attr_reader :from_name
    
    # The new state value *after* the transition
    attr_reader :to
    
    # The new state name *after* the transition
    attr_reader :to_name
    
    # Creates a new, specific transition
    def initialize(object, machine, event, from_name, to_name) #:nodoc:
      @object = object
      @machine = machine
      @event = event
      @from = object.send(machine.attribute)
      @from_name = from_name
      @to = machine.states[to_name].value
      @to_name = to_name
    end
    
    # Gets the attribute which this transition's machine is defined for
    def attribute
      machine.attribute
    end
    
    # Gets a hash of all the core attributes defined for this transition with
    # their names as keys and values of the attributes as values.
    # 
    # == Example
    # 
    #   machine = StateMachine.new(Vehicle)
    #   transition = StateMachine::Transition.new(Vehicle.new, machine, :ignite, :parked, :idling)
    #   transition.attributes   # => {:object => #<Vehicle:0xb7d60ea4>, :attribute => :state, :event => :ignite, :from => 'parked', :to => 'idling'}
    def attributes
      @attributes ||= {:object => object, :attribute => attribute, :event => event, :from => from, :to => to}
    end
    
    # Runs the actual transition and any before/after callbacks associated
    # with the transition.  The action associated with the transition/machine
    # can be skipped by passing in +false+.
    # 
    # == Examples
    # 
    #   class Vehicle
    #     state_machine :action => :save do
    #       ...
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new
    #   transition = StateMachine::Transition.new(vehicle, machine, :ignite, :parked, :idling)
    #   transition.perform          # => Runs the +save+ action after setting the state attribute
    #   transition.perform(false)   # => Only sets the state attribute
    def perform(run_action = true)
      result = false
      
      machine.within_transaction(object) do
        catch(:halt) do
          # Run before callbacks
          callback(:before)
          
          # Updates the object's attribute to the ending state
          object.send("#{attribute}=", to)
          result = run_action && machine.action ? object.send(machine.action) != false : true
          
          # Always run after callbacks regardless of whether the action failed.
          # Result is included in case the callback depends on this value
          callback(:after, result)
        end
        
        # Make sure the transaction gets the correct return value for determining
        # whether it should rollback or not
        result = result != false
      end
      
      result
    end
    
    # Generates a nicely formatted description of this transitions's contents.
    # 
    # For example,
    # 
    #   transition = StateMachine::Transition.new(object, machine, :ignite, :parked, :idling)
    #   transition   # => #<StateMachine::Transition attribute=:state event=:ignite from="parked" from_name=:parked to="idling" to_name=:idling>
    def inspect
      "#<#{self.class} #{%w(attribute event from from_name to to_name).map {|attr| "#{attr}=#{send(attr).inspect}"} * ' '}>"
    end
    
    protected
      # Gets a hash of the context defining this unique transition (including
      # event, from state, and to state).
      # 
      # == Example
      # 
      #   machine = StateMachine.new(Vehicle)
      #   transition = StateMachine::Transition.new(Vehicle.new, machine, :ignite, :parked, :idling)
      #   transition.context    # => {:on => :ignite, :from => :parked, :to => :idling}
      def context
        @context ||= {:on => event, :from => from_name, :to => to_name}
      end
      
      # Runs the callbacks of the given type for this transition.  This will
      # only invoke callbacks that exactly match the event, from state, and
      # to state that describe this transition.
      # 
      # Additional callback parameters can be specified.  By default, this
      # transition is also passed into callbacks.
      def callback(type, *args)
        machine.callbacks[type].each do |callback|
          callback.call(object, context, self, *args)
        end
      end
  end
end
