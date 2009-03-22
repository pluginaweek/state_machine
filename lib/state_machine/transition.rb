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
    class << self
      # Runs one or more transitions in parallel.  All transitions will run
      # through the following steps:
      # * Before callbacks
      # * Persist state
      # * Invoke action
      # * After callbacks
      # 
      # See StateMachine::InstanceMethods#run_events for more information.
      def perform(transitions, run_action = true)
        # Validate that the transitions are for separate machines / attributes
        attributes = transitions.map {|transition| transition.attribute}.uniq
        raise ArgumentError, 'Cannot perform multiple transitions in parallel for the same state machine / attribute' if attributes.length != transitions.length
        
        result = false
        
        # Grab any transition for wrapping flow within a transaction
        transitions.first.within_transaction do
          catch(:halt) do
            # Run before callbacks.  If any callback halts, then the entire
            # chain is halted for every transition.
            transitions.each {|transition| transition.before}
            
            # Persist the new state for each attribute
            transitions.each {|transition| transition.persist}
            
            # Run the actions associated with each machine
            actions = transitions.map {|transition| transition.action}.uniq.compact
            object = transitions.first.object
            result = !run_action || actions.all? {|action| object.send(action) != false}
            
            # Always run after callbacks regardless of whether the actions failed
            transitions.each {|transition| transition.after(result)}
          end
          
          # Make sure the transaction gets the correct return value for determining
          # whether it should rollback or not
          result = result != false
        end

        result
      end
    end
    
    # The object being transitioned
    attr_reader :object
    
    # The state machine for which this transition is defined
    attr_reader :machine
    
    # The event that triggered the transition
    attr_reader :event
    
    # The fully-qualified name of the event that triggered the transition
    attr_reader :qualified_event
    
    # The original state value *before* the transition
    attr_reader :from
    
    # The original state name *before* the transition
    attr_reader :from_name
    
    # The original fully-qualified state name *before* transition
    attr_reader :qualified_from_name
    
    # The new state value *after* the transition
    attr_reader :to
    
    # The new state name *after* the transition
    attr_reader :to_name
    
    # The new fully-qualified state name *after* the transition
    attr_reader :qualified_to_name
    
    # The arguments passed in to the event that triggered the transition
    # (does not include the +run_action+ boolean argument if specified)
    attr_accessor :args
    
    # Creates a new, specific transition
    def initialize(object, machine, event, from_name, to_name) #:nodoc:
      @object = object
      @machine = machine
      
      # Event information
      if event = machine.events[event]
        @event = event.name
        @qualified_event = event.qualified_name
      end
      
      # From state information
      from_state = machine.states.fetch(from_name)
      @from = machine.read(object)
      @from_name = from_state.name
      @qualified_from_name = from_state.qualified_name
      
      # To state information
      to_state = machine.states.fetch(to_name)
      @to = to_state.value
      @to_name = to_state.name
      @qualified_to_name = to_state.qualified_name
    end
    
    # The attribute which this transition's machine is defined for
    def attribute
      machine.attribute
    end
    
    # The action that will be run when this transition is performed
    def action
      machine.action
    end
    
    # A hash of all the core attributes defined for this transition with their
    # names as keys and values of the attributes as values.
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
    def perform(*args)
      run_action = [true, false].include?(args.last) ? args.pop : true
      self.args = args
      
      # Run the transition
      self.class.perform([self], run_action)
    end
    
    # Runs a block within a transaction for the object being transitioned.
    # By default, transactions are a no-op unless otherwise defined by the
    # machine's integration.
    def within_transaction
      machine.within_transaction(object) do
        yield
      end
    end
    
    # Runs the machine's +before+ callbacks for this transition.  Only
    # callbacks that are configured to match the event, from state, and to
    # state will be invoked.
    # 
    # == Example
    # 
    #   class Vehicle
    #     state_machine do
    #       before_transition :on => :ignite, :do => lambda {|vehicle| ...}
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new
    #   transition = StateMachine::Transition.new(vehicle, machine, :ignite, :parked, :idling)
    #   transition.before
    def before
      callback(:before)
    end
    
    # Transitions the current value of the state to that specified by the
    # transition.
    # 
    # == Example
    # 
    #   class Vehicle
    #     state_machine do
    #       ...
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new
    #   transition = StateMachine::Transition.new(vehicle, machine, :ignite, :parked, :idling)
    #   transition.persist
    #   
    #   vehicle.state   # => 'idling'
    def persist
      machine.write(object, to)
    end
    
    # Runs the machine's +after+ callbacks for this transition.  Only
    # callbacks that are configured to match the event, from state, and to
    # state will be invoked.
    # 
    # The result is used to indicate whether the associated machine action
    # was executed successfully.
    # 
    # == Halting
    # 
    # If any callback throws a <tt>:halt</tt> exception, it will be caught
    # and the callback chain will be automatically stopped.  However, this
    # exception will not bubble up to the caller since +after+ callbacks
    # should never halt the execution of a +perform+.
    # 
    # == Example
    # 
    #   class Vehicle
    #     state_machine do
    #       after_transition :on => :ignite, :do => lambda {|vehicle| ...}
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new
    #   transition = StateMachine::Transition.new(vehicle, machine, :ignite, :parked, :idling)
    #   transition.after(true)
    def after(result)
      catch(:halt) do
        callback(:after, result)
      end
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
