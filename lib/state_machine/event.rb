require 'state_machine/transition'
require 'state_machine/guard'
require 'state_machine/assertions'
require 'state_machine/matcher_helpers'

module StateMachine
  # An invalid event was specified
  class InvalidEvent < StandardError
  end
  
  # An event defines an action that transitions an attribute from one state to
  # another.  The state that an attribute is transitioned to depends on the
  # guards configured for the event.
  class Event
    include Assertions
    include MatcherHelpers
    
    # The state machine for which this event is defined
    attr_accessor :machine
    
    # The name of the event
    attr_reader :name
    
    # The fully-qualified name of the event, scoped by the machine's namespace 
    attr_reader :qualified_name
    
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
      @qualified_name = machine.namespace ? :"#{name}_#{machine.namespace}" : name
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
    
    # Creates a new transition that determines what to change the current state
    # to when this event fires.
    # 
    # == Defining transitions
    # 
    # The options for a new transition uses the Hash syntax to map beginning
    # states to ending states.  For example,
    # 
    #   transition :parked => :idling, :idling => :first_gear
    # 
    # In this case, when the event is fired, this transition will cause the
    # state to be +idling+ if it's current state is +parked+ or +first_gear+
    # if it's current state is +idling+.
    # 
    # To help defining these implicit transitions, a set of helpers are available
    # for defining slightly more complex matching:
    # * <tt>all</tt> - Matches every state in the machine
    # * <tt>all - [:parked, :idling, ...]</tt> - Matches every state except those specified
    # * <tt>any</tt> - An alias for +all+ (matches every state in the machine)
    # * <tt>same</tt> - Matches the same state being transitioned from
    # 
    # See StateMachine::MatcherHelpers for more information.
    # 
    # Examples:
    # 
    #   transition all => nil                               # Transitions to nil regardless of the current state
    #   transition all => :idling                           # Transitions to :idling regardless of the current state
    #   transition all - [:idling, :first_gear] => :idling  # Transitions every state but :idling and :first_gear to :idling
    #   transition nil => :idling                           # Transitions to :idling from the nil state
    #   transition :parked => :idling                       # Transitions to :idling if :parked
    #   transition [:parked, :stalled] => :idling           # Transitions to :idling if :parked or :stalled
    #   
    #   transition :parked => same                          # Loops :parked back to :parked
    #   transition [:parked, :stalled] => same              # Loops either :parked or :stalled back to the same state
    #   transition all - :parked => same                    # Loops every state but :parked back to the same state
    # 
    # == Verbose transitions
    # 
    # Transitions can also be defined use an explicit set of deprecated
    # configuration options:
    # * <tt>:from</tt> - A state or array of states that can be transitioned from.
    #   If not specified, then the transition can occur for *any* state.
    # * <tt>:to</tt> - The state that's being transitioned to.  If not specified,
    #   then the transition will simply loop back (i.e. the state will not change).
    # * <tt>:except_from</tt> - A state or array of states that *cannot* be
    #   transitioned from.
    # 
    # Examples:
    # 
    #   transition :to => nil
    #   transition :to => :idling
    #   transition :except_from => [:idling, :first_gear], :to => :idling
    #   transition :from => nil, :to => :idling
    #   transition :from => [:parked, :stalled], :to => :idling
    #   
    #   transition :from => :parked
    #   transition :from => [:parked, :stalled]
    #   transition :except_from => :parked
    # 
    # Notice that the above examples are the verbose equivalent of the examples
    # described initially.
    # 
    # == Conditions
    # 
    # In addition to the state requirements for each transition, a condition
    # can also be defined to help determine whether that transition is
    # available.  These options will work on both the normal and verbose syntax.
    # 
    # Configuration options:
    # * <tt>:if</tt> - A method, proc or string to call to determine if the
    #   transition should occur (e.g. :if => :moving?, or :if => lambda {|vehicle| vehicle.speed > 60}).
    #   The condition should return or evaluate to true or false.
    # * <tt>:unless</tt> - A method, proc or string to call to determine if the
    #   transition should not occur (e.g. :unless => :stopped?, or :unless => lambda {|vehicle| vehicle.speed <= 60}).
    #   The condition should return or evaluate to true or false.
    # 
    # Examples:
    # 
    #   transition :parked => :idling, :if => :moving?
    #   transition :parked => :idling, :unless => :stopped?
    #   
    #   transition :from => :parked, :to => :idling, :if => :moving?
    #   transition :from => :parked, :to => :idling, :unless => :stopped?
    # 
    # == Order of operations
    # 
    # Transitions are evaluated in the order in which they're defined.  As a
    # result, if more than one transition applies to a given object, then the
    # first transition that matches will be performed.
    def transition(options)
      raise ArgumentError, 'Must specify as least one transition requirement' if options.empty?
      
      # Only a certain subset of explicit options are allowed for transition
      # requirements
      assert_valid_keys(options, :from, :to, :except_from, :if, :unless) if (options.keys - [:from, :to, :on, :except_from, :except_to, :except_on, :if, :unless]).empty?
      
      guards << guard = Guard.new(options)
      @known_states |= guard.known_states
      guard
    end
    
    # Determines whether any transitions can be performed for this event based
    # on the current state of the given object.
    # 
    # If the event can't be fired, then this will return false, otherwise true.
    def can_fire?(object)
      !transition_for(object).nil?
    end
    
    # Finds and builds the next transition that can be performed on the given
    # object.  If no transitions can be made, then this will return nil.
    def transition_for(object)
      from = machine.states.match(object).name
      
      guards.each do |guard|
        if match = guard.match(object, :from => from)
          # Guard allows for the transition to occur
          to = match[:to].values.empty? ? from : match[:to].values.first
          
          return Transition.new(object, machine, name, from, to)
        end
      end
      
      # No transition matched
      nil
    end
    
    # Attempts to perform the next available transition on the given object.
    # If no transitions can be made, then this will return false, otherwise
    # true.
    # 
    # Any additional arguments are passed to the StateMachine::Transition#perform
    # instance method.
    def fire(object, *args)
      machine.reset(object)
      
      if transition = transition_for(object)
        transition.perform(*args)
      else
        machine.invalidate(object, machine.attribute, :invalid_transition, [[:event, name]])
        false
      end
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
    #   event.transition all - :idling => :parked, :idling => same
    #   event   # => #<StateMachine::Event name=:park transitions=[all - :idling => :parked, :idling => same]>
    def inspect
      transitions = guards.map do |guard|
        guard.state_requirements.map do |state_requirement|
          "#{state_requirement[:from].description} => #{state_requirement[:to].description}"
        end * ', '
      end
      
      "#<#{self.class} name=#{name.inspect} transitions=[#{transitions * ', '}]>"
    end
    
    protected
      # Add the various instance methods that can transition the object using
      # the current event
      def add_actions
        # Checks whether the event can be fired on the current object
        machine.define_instance_method("can_#{qualified_name}?") do |machine, object|
          machine.event(name).can_fire?(object)
        end
        
        # Gets the next transition that would be performed if the event were
        # fired now
        machine.define_instance_method("#{qualified_name}_transition") do |machine, object|
          machine.event(name).transition_for(object)
        end
        
        # Fires the event
        machine.define_instance_method(qualified_name) do |machine, object, *args|
          machine.event(name).fire(object, *args)
        end
        
        # Fires the event, raising an exception if it fails
        machine.define_instance_method("#{qualified_name}!") do |machine, object, *args|
          object.send(qualified_name, *args) || raise(StateMachine::InvalidTransition, "Cannot transition #{machine.attribute} via :#{name} from #{machine.states.match(object).name.inspect}")
        end
      end
  end
end
