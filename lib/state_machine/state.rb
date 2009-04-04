require 'state_machine/assertions'
require 'state_machine/condition_proxy'

module StateMachine
  # A state defines a value that an attribute can be in after being transitioned
  # 0 or more times.  States can represent a value of any type in Ruby, though
  # the most common (and default) type is String.
  # 
  # In addition to defining the machine's value, a state can also define a
  # behavioral context for an object when that object is in the state.  See
  # StateMachine::Machine#state for more information about how state-driven
  # behavior can be utilized.
  class State
    include Assertions
    
    # The state machine for which this state is defined
    attr_accessor :machine
    
    # The unique identifier for the state used in event and callback definitions
    attr_reader :name
    
    # The fully-qualified identifier for the state, scoped by the machine's
    # namespace
    attr_reader :qualified_name
    
    # The value that is written to a machine's attribute when an object
    # transitions into this state
    attr_writer :value
    
    # Whether or not this state is the initial state to use for new objects
    attr_accessor :initial
    alias_method :initial?, :initial
    
    # A custom lambda block for determining whether a given value matches this
    # state
    attr_accessor :matcher
    
    # Tracks all of the methods that have been defined for the machine's owner
    # class when objects are in this state.
    # 
    # Maps :method_name => UnboundMethod
    attr_reader :methods
    
    # Creates a new state within the context of the given machine.
    # 
    # Configuration options:
    # * <tt>:initial</tt> - Whether this state is the beginning state for the
    #   machine. Default is false.
    # * <tt>:value</tt> - The value to store when an object transitions to this
    #   state.  Default is the name (stringified).
    # * <tt>:if</tt> - Determines whether a value matches this state
    #   (e.g. :value => lambda {Time.now}, :if => lambda {|state| !state.nil?}).
    #   By default, the configured value is matched.
    def initialize(machine, name, options = {}) #:nodoc:
      assert_valid_keys(options, :initial, :value, :if)
      
      @machine = machine
      @name = name
      @qualified_name = name && machine.namespace ? :"#{machine.namespace}_#{name}" : name
      @value = options.include?(:value) ? options[:value] : name && name.to_s
      @matcher = options[:if]
      @methods = {}
      @initial = options[:initial] == true
      
      add_predicate
    end
    
    # Creates a copy of this state in addition to the list of associated
    # methods to prevent conflicts across different states.
    def initialize_copy(orig) #:nodoc:
      super
      @methods = methods.dup
    end
    
    # Determines whether there are any states that can be transitioned to from
    # this state.  If there are none, then this state is considered *final*.
    # Any objects in a final state will remain so forever given the current
    # machine's definition.
    def final?
      !machine.events.any? do |event|
        event.guards.any? do |guard|
          guard.state_requirements.any? do |requirement|
            requirement[:from].matches?(name) && !requirement[:to].matches?(name, :from => name)
          end
        end
      end
    end
    
    # Generates a human-readable description of this state's name / value:
    # 
    # For example,
    # 
    #   State.new(machine, :parked).description                               # => "parked"
    #   State.new(machine, :parked, :value => :parked).description            # => "parked"
    #   State.new(machine, :parked, :value => nil).description                # => "parked (nil)"
    #   State.new(machine, :parked, :value => 1).description                  # => "parked (1)"
    #   State.new(machine, :parked, :value => lambda {Time.now}).description  # => "parked (*)
    def description
      description = name ? name.to_s : name.inspect
      description << " (#{@value.is_a?(Proc) ? '*' : @value.inspect})" unless name.to_s == @value.to_s
      description
    end
    
    # The value that represents this state.  If the value is a lambda block,
    # then it will be evaluated at this time.  Otherwise, the static value is
    # returned.
    # 
    # For example,
    # 
    #   State.new(machine, :parked, :value => 1).value                  # => 1
    #   State.new(machine, :parked, :value => lambda {Time.now}).value  # => Tue Jan 01 00:00:00 UTC 2008
    def value
      @value.is_a?(Proc) ? @value.call : @value
    end
    
    # Determines whether this state matches the given value.  If no matcher is
    # configured, then this will check whether the values are equivalent.
    # Otherwise, the matcher will determine the result.
    # 
    # For example,
    # 
    #   # Without a matcher
    #   state = State.new(machine, :parked, :value => 1)
    #   state.matches?(1)           # => true
    #   state.matches?(2)           # => false
    #   
    #   # With a matcher
    #   state = State.new(machine, :parked, :value => lambda {Time.now}, :if => lambda {|value| !value.nil?})
    #   state.matches?(nil)         # => false
    #   state.matches?(Time.now)    # => true
    def matches?(other_value)
      matcher ? matcher.call(other_value) : other_value == value
    end
    
    # Defines a context for the state which will be enabled on instances of
    # the owner class when the machine is in this state.
    # 
    # This can be called multiple times.  Each time a new context is created,
    # a new module will be included in the owner class.
    def context(&block)
      owner_class = machine.owner_class
      attribute = machine.attribute
      name = self.name
      
      # Evaluate the method definitions
      context = ConditionProxy.new(owner_class, lambda {|object| object.send("#{attribute}_name") == name})
      context.class_eval(&block)
      context.instance_methods.each do |method|
        methods[method.to_sym] = context.instance_method(method)
        
        # Calls the method defined by the current state of the machine
        context.class_eval <<-end_eval, __FILE__, __LINE__
          def #{method}(*args, &block)
            self.class.state_machine(#{attribute.inspect}).states.match(self).call(self, #{method.inspect}, *args, &block)
          end
        end_eval
      end
      
      # Include the context so that it can be bound to the owner class (the
      # context is considered an ancestor, so it's allowed to be bound)
      owner_class.class_eval { include context }
      
      context
    end
    
    # Calls a method defined in this state's context on the given object.  All
    # arguments and any block will be passed into the method defined.
    # 
    # If the method has never been defined for this state, then a NoMethodError
    # will be raised.
    def call(object, method, *args, &block)
      if context_method = methods[method.to_sym]
        # Method is defined by the state: proxy it through
        context_method.bind(object).call(*args, &block)
      else
        # Raise exception as if the method never existed on the original object
        raise NoMethodError, "undefined method '#{method}' for #{object} in state #{machine.states.match(object).name.inspect}"
      end
    end
    
    # Draws a representation of this state on the given machine.  This will
    # create a new node on the graph with the following properties:
    # * +label+ - The human-friendly description of the state.
    # * +width+ - The width of the node.  Always 1.
    # * +height+ - The height of the node.  Always 1.
    # * +shape+ - The actual shape of the node.  If the state is a final
    #   state, then "doublecircle", otherwise "ellipse".
    # 
    # The actual node generated on the graph will be returned.
    def draw(graph)
      node = graph.add_node(name ? name.to_s : 'nil',
        :label => description,
        :width => '1',
        :height => '1',
        :shape => final? ? 'doublecircle' : 'ellipse'
      )
      
      # Add open arrow for initial state
      graph.add_edge(graph.add_node('starting_state', :shape => 'point'), node) if initial?
      
      node
    end
    
    # Generates a nicely formatted description of this state's contents.
    # 
    # For example,
    # 
    #   state = StateMachine::State.new(machine, :parked, :value => 1, :initial => true)
    #   state   # => #<StateMachine::State name=:parked value=1 initial=true context=[]>
    def inspect
      attributes = [[:name, name], [:value, @value], [:initial, initial?], [:context, methods.keys]]
      "#<#{self.class} #{attributes.map {|attr, value| "#{attr}=#{value.inspect}"} * ' '}>"
    end
    
    private
      # Adds a predicate method to the owner class so long as a name has
      # actually been configured for the state
      def add_predicate
        return unless name
        
        # Checks whether the current value matches this state
        machine.define_instance_method("#{qualified_name}?") do |machine, object|
          machine.states.matches?(object, name)
        end
      end
  end
end
