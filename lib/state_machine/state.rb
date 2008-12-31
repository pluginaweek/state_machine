require 'state_machine/assertions'

module StateMachine
  # A state defines a value that an attribute can be in after being transitioned
  # 0 or more times.  States can represent a value of any type in Ruby, though
  # the most common type is String.
  # 
  # In addition to defining the machine's value, states can also define a
  # behavioral context for an object when that object is in the state.  See
  # StateMachine::Machine#state for more information about how state-driven
  # behavior can be utilized.
  class State
    include Assertions
    
    class << self
      # Generates a unique identifier for the given state value.  Ids are based
      # on the object type:
      # * Proc - "lambda#{object_id}"
      # * NilClass - "nil"
      # * Everything else - Stringified version of the object
      def id_for(value)
        case value
        when Proc
          "lambda#{value.object_id.abs}"
        when nil
          'nil'
        else
          value.to_s
        end
      end
    end
    
    # The state machine for which this state is defined
    attr_accessor :machine
    
    # Tracks all of the methods that have been defined for the machine's owner
    # class when objects are in this state.
    # 
    # Maps "method name" => UnboundMethod
    attr_reader :methods
    
    # Whether or not this state in the initial state to use for new objects
    attr_accessor :initial
    
    # Creates a new state within the context of the given machine
    # 
    # Configuration options:
    # * +initial+ - Whether this state is the beginning state for the machine.  Default is false.
    def initialize(machine, value, options = {}) #:nodoc:
      assert_valid_keys(options, :initial)
      
      @machine = machine
      @value = value
      @methods = {}
      @initial = options.include?(:initial) && options[:initial]
      
      add_predicate
    end
    
    # Creates a copy of this state in addition to the list of associated
    # methods to prevent conflicts across different states.
    def initialize_copy(orig) #:nodoc:
      super
      @methods = @methods.dup
    end
    
    # The value (of any type) that represents this state.  If an object is
    # passed in and the state's value is a lambda block, then the object will be
    # passed into the block to generate the actual value of the state.
    def value(object = nil)
      @value.is_a?(Proc) && object ? @value.call(object) : @value
    end
    
    # Defines a context for the state which will be enabled on instances of the
    # owner class when the machine is in this state.
    # 
    # This can be called multiple times.  Each time a new context is created, a
    # new module will be included in the owner class.
    def context(&block)
      value = self.value
      owner_class = machine.owner_class
      attribute = machine.attribute
      
      # Evaluate the method definitions
      context = Module.new
      context.class_eval(&block)
      
      # Define all of the methods that were created in the module so that they
      # don't override the core behavior (i.e. calling the state method)
      context.instance_methods.each do |method|
        unless owner_class.instance_methods.include?(method)
          # Calls the method defined by the current state of the machine.  This
          # is done using string evaluation so that any block passed into the
          # method can then be passed to the state's context method, which is
          # not possible with lambdas in Ruby 1.8.6.
          owner_class.class_eval <<-end_eval, __FILE__, __LINE__
            def #{method}(*args, &block)
              attribute = #{attribute.dump}
              self.class.state_machines[attribute].state(send(attribute)).call(self, #{method.to_s.dump}, *args, &block)
            end
          end_eval
        end
        
        # Track the method defined for the context so that it can be invoked
        # at a later point in time
        methods[method.to_sym] = context.instance_method(method)
      end
      
      # Include the context so that it can be bound to the owner class (the
      # context is considered an ancestor, so it's allowed to be bound)
      owner_class.class_eval do
        include context
      end
      
      methods
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
        raise NoMethodError, "undefined method '#{method}' for #{object} in state #{object.send(machine.attribute).inspect}"
      end
    end
    
    # Draws a representation of this state on the given machine.  This will
    # create a new node on the graph with the following properties:
    # * +label+ - A human-friendly version of the value.  For lambda blocks / procs, "*", otherwise the stringified version of the value is used.
    # * +width+ - The width of the node.  Always 1.
    # * +height+ - The height of the node.  Always 1.
    # * +fixedsize+ - Whether the size of the node stays the same regardless of its contents.  Always true.
    # * +shape+ - The actual shape of the node.  If the state is the beginning state, then "doublecircle", otherwise "circle".
    # 
    # The actual node generated on the graph will be returned.
    def draw(graph)
      shape = initial ? 'doublecircle' : 'circle'
      
      # Use GraphViz-friendly name/label for dynamic/nil states
      name = self.class.id_for(value)
      if value.is_a?(Proc)
        label = '*'
      else
        label = value.nil? ? 'nil' : value.to_s
      end
      
      graph.add_node(name, :label => label, :width => '1', :height => '1', :fixedsize => 'true', :shape => shape)
    end
    
    private
      # Adds a predicate method to the owner class as long as this state's value
      # is a string/symbol
      def add_predicate
        if value && (value.is_a?(String) || value.is_a?(Symbol))
          attribute = machine.attribute
          value = self.value
          name = "#{value}?"
          name = "#{machine.namespace}_#{name}" if machine.namespace
          
          machine.owner_class.class_eval do
            # Checks whether the current state is equal to the given value
            define_method(name) do
              self.send(attribute) == value
            end unless method_defined?(name) || private_method_defined?(name)
          end
        end
      end
  end
end
