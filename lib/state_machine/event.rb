require 'state_machine/transition'
require 'state_machine/guard'
require 'state_machine/assertions'

module StateMachine
  # An event defines an action that transitions an attribute from one state to
  # another.  The state that an attribute is transitioned to depends on the
  # guards configured for the event.
  class Event
    include Assertions
    
    # The state machine for which this event is defined
    attr_accessor :machine
    
    # The name of the action that fires the event
    attr_reader :name
    
    # The list of guards that determine what state this event transitions
    # objects to when fired
    attr_reader :guards
    
    # A list of all of the states known to this event using the configured
    # guards/transitions as the source
    attr_reader :known_states
    
    # Creates a new event within the context of the given machine
    def initialize(machine, name) #:nodoc:
      @machine = machine
      @name = name
      @guards = []
      @known_states = []
      
      add_actions
    end
    
    # Creates a copy of this event in addition to the list of associated
    # guards to prevent conflicts across events within a class hierarchy.
    def initialize_copy(orig) #:nodoc:
      super
      @guards = @guards.dup
      @known_states = @known_states.dup
    end
    
    # Creates a new transition that will be evaluated when the event is fired.
    # 
    # Configuration options:
    # * <tt>:from</tt> - A state or array of states that can be transitioned from.
    #   If not specified, then the transition can occur for *any* state.
    # * <tt>:to</tt> - The state that's being transitioned to.  If not specified,
    #   then the transition will simply loop back (i.e. the state will not change).
    # * <tt>:except_from</tt> - A state or array of states that *cannot* be
    #   transitioned from.
    # * <tt>:if</tt> - A method, proc or string to call to determine if the
    #   transition should occur (e.g. :if => :moving?, or :if => lambda {|vehicle| vehicle.speed > 60}).
    #   The condition should return or evaluate to true or false.
    # * <tt>:unless</tt> - A method, proc or string to call to determine if the
    #   transition should not occur (e.g. :unless => :stopped?, or :unless => lambda {|vehicle| vehicle.speed <= 60}).
    #   The condition should return or evaluate to true or false.
    # 
    # == Order of operations
    # 
    # Transitions are evaluated in the order in which they're defined.  As a
    # result, if more than one transition applies to a given object, then the
    # first transition that matches will be performed.
    # 
    # == Examples
    # 
    #   transition :from => nil, :to => :parked
    #   transition :from => [:first_gear, :reverse]
    #   transition :except_from => :parked
    #   transition :to => nil
    #   transition :to => :parked
    #   transition :to => :parked, :from => :first_gear
    #   transition :to => :parked, :from => [:first_gear, :reverse]
    #   transition :to => :parked, :from => :first_gear, :if => :moving?
    #   transition :to => :parked, :from => :first_gear, :unless => :stopped?
    #   transition :to => :parked, :except_from => :parked
    def transition(options)
      assert_valid_keys(options, :from, :to, :except_from, :if, :unless)
      
      guards << guard = Guard.new(options)
      @known_states |= guard.known_states
      guard
    end
    
    # Determines whether any transitions can be performed for this event based
    # on the current state of the given object.
    # 
    # If the event can't be fired, then this will return false, otherwise true.
    def can_fire?(object)
      !next_transition(object).nil?
    end
    
    # Finds and builds the next transition that can be performed on the given
    # object.  If no transitions can be made, then this will return nil.
    def next_transition(object)
      from = machine.state_for(object).name
      
      if guard = guards.find {|guard| guard.matches?(object, :from => from)}
        # Guard allows for the transition to occur
        to = guard.requirements[:to] ? guard.requirements[:to].first : from
        Transition.new(object, machine, name, from, to)
      end
    end
    
    # Attempts to perform the next available transition on the given object.
    # If no transitions can be made, then this will return false, otherwise
    # true.
    # 
    # Any additional arguments are passed to the StateMachine::Transition#perform
    # instance method.
    def fire(object, *args)
      if transition = next_transition(object)
        transition.perform(*args)
      else
        false
      end
    end
    
    # Attempts to perform the next available transition on the given object.
    # If no transitions can be made, then a StateMachine::InvalidTransition
    # exception will be raised, otherwise true will be returned.
    def fire!(object, *args)
      fire(object, *args) || raise(StateMachine::InvalidTransition, "Cannot transition #{machine.attribute} via :#{name} from #{machine.state_for(object).name.inspect}")
    end
    
    # Draws a representation of this event on the given graph.  This will
    # create 1 or more edges on the graph for each guard (i.e. transition)
    # configured.
    # 
    # A collection of the generated edges will be returned.
    def draw(graph)
      valid_states = machine.states.by_priority.map {|state| state.name}
      guards.collect {|guard| guard.draw(graph, name, valid_states)}.flatten
    end
    
    # Generates a nicely formatted description of this events's contents.
    # 
    # For example,
    # 
    #   event = StateMachine::Event.new(machine, :park)
    #   event.transition :to => :parked, :from => :idling
    #   event   # => #<StateMachine::Event name=:park transitions=[{:to => [:parked], :from => [:idling]}]>
    def inspect
      attributes = [[:name, name], [:transitions, guards.map {|guard| guard.requirements}]]
      "#<#{self.class} #{attributes.map {|name, value| "#{name}=#{value.inspect}"} * ' '}>"
    end
    
    protected
      # Add the various instance methods that can transition the object using
      # the current event
      def add_actions
        attribute = machine.attribute
        qualified_name = name = self.name
        qualified_name = "#{name}_#{machine.namespace}" if machine.namespace
        
        machine.owner_class.class_eval do
          # Checks whether the event can be fired on the current object
          define_method("can_#{qualified_name}?") do
            self.class.state_machines[attribute].event(name).can_fire?(self)
          end
          
          # Gets the next transition that would be performed if the event were
          # fired now
          define_method("next_#{qualified_name}_transition") do
            self.class.state_machines[attribute].event(name).next_transition(self)
          end
          
          # Fires the event
          define_method(qualified_name) do |*args|
            self.class.state_machines[attribute].event(name).fire(self, *args)
          end
          
          # Fires the event, raising an exception if it fails
          define_method("#{qualified_name}!") do |*args|
            self.class.state_machines[attribute].event(name).fire!(self, *args)
          end
        end
      end
  end
end
