require 'state_machine/assertions'
require 'state_machine/state_context'

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
    
    # The human-readable name for the state
    attr_writer :human_name
    
    # The value that is written to a machine's attribute when an object
    # transitions into this state
    attr_writer :value
    
    # Whether this state's value should be cached after being evaluated
    attr_accessor :cache
    
    # Whether or not this state is the initial state to use for new objects
    attr_accessor :initial
    alias_method :initial?, :initial
    
    # A custom lambda block for determining whether a given value matches this
    # state
    attr_accessor :matcher
    
    # Creates a new state within the context of the given machine.
    # 
    # Configuration options:
    # * <tt>:initial</tt> - Whether this state is the beginning state for the
    #   machine. Default is false.
    # * <tt>:value</tt> - The value to store when an object transitions to this
    #   state.  Default is the name (stringified).
    # * <tt>:cache</tt> - If a dynamic value (via a lambda block) is being used,
    #   then setting this to true will cache the evaluated result
    # * <tt>:if</tt> - Determines whether a value matches this state
    #   (e.g. :value => lambda {Time.now}, :if => lambda {|state| !state.nil?}).
    #   By default, the configured value is matched.
    # * <tt>:human_name</tt> - The human-readable version of this state's name
    def initialize(machine, name, options = {}) #:nodoc:
      assert_valid_keys(options, :initial, :value, :cache, :if, :human_name)
      
      @machine = machine
      @name = name
      @qualified_name = name && machine.namespace ? :"#{machine.namespace}_#{name}" : name
      @human_name = options[:human_name] || (@name ? @name.to_s.tr('_', ' ') : 'nil')
      @value = options.include?(:value) ? options[:value] : name && name.to_s
      @cache = options[:cache]
      @matcher = options[:if]
      @initial = options[:initial] == true
      @context = StateContext.new(self)
      
      if name
        conflicting_machines = machine.owner_class.state_machines.select {|other_name, other_machine| other_machine != machine && other_machine.states[qualified_name, :qualified_name]}
        
        # Output a warning if another machine has a conflicting qualified name
        # for a different attribute
        if conflict = conflicting_machines.detect {|other_name, other_machine| other_machine.attribute != machine.attribute}
          name, other_machine = conflict
          warn "State #{qualified_name.inspect} for #{machine.name.inspect} is already defined in #{other_machine.name.inspect}"
        elsif conflicting_machines.empty?
          # Only bother adding predicates when another machine for the same
          # attribute hasn't already done so
          add_predicate
        end
      end
    end
    
    # Creates a copy of this state, excluding the context to prevent conflicts
    # across different machines.
    def initialize_copy(orig) #:nodoc:
      super
      @context = StateContext.new(self)
    end
    
    # Determines whether there are any states that can be transitioned to from
    # this state.  If there are none, then this state is considered *final*.
    # Any objects in a final state will remain so forever given the current
    # machine's definition.
    def final?
      !machine.events.any? do |event|
        event.branches.any? do |branch|
          branch.state_requirements.any? do |requirement|
            requirement[:from].matches?(name) && !requirement[:to].matches?(name, :from => name)
          end
        end
      end
    end
    
    # Transforms the state name into a more human-readable format, such as
    # "first gear" instead of "first_gear"
    def human_name(klass = @machine.owner_class)
      @human_name.is_a?(Proc) ? @human_name.call(self, klass) : @human_name
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
    # 
    # Configuration options:
    # * <tt>:human_name</tt> - Whether to use this state's human name in the
    #   description or just the internal name
    def description(options = {})
      label = options[:human_name] ? human_name : name
      description = label ? label.to_s : label.inspect
      description << " (#{@value.is_a?(Proc) ? '*' : @value.inspect})" unless name.to_s == @value.to_s
      description
    end
    
    # The value that represents this state.  This will optionally evaluate the
    # original block if it's a lambda block.  Otherwise, the static value is
    # returned.
    # 
    # For example,
    # 
    #   State.new(machine, :parked, :value => 1).value                        # => 1
    #   State.new(machine, :parked, :value => lambda {Time.now}).value        # => Tue Jan 01 00:00:00 UTC 2008
    #   State.new(machine, :parked, :value => lambda {Time.now}).value(false) # => <Proc:0xb6ea7ca0@...>
    def value(eval = true)
      if @value.is_a?(Proc) && eval
        if cache_value?
          @value = @value.call
          machine.states.update(self)
          @value
        else
          @value.call
        end
      else
        @value
      end
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
      # Include the context
      context = @context
      machine.owner_class.class_eval { include context }
      
      # Evaluate the method definitions and track which ones were added
      old_methods = context_methods
      context.class_eval(&block)
      new_methods = context_methods.to_a.select {|(name, method)| old_methods[name] != method}
      
      # Alias new methods so that the only execute when the object is in this state
      new_methods.each do |(method_name, method)|
        context_name = context_name_for(method_name)
        context.class_eval <<-end_eval, __FILE__, __LINE__ + 1
          alias_method :"#{context_name}", :#{method_name}
          def #{method_name}(*args, &block)
            state = self.class.state_machine(#{machine.name.inspect}).states.fetch(#{name.inspect})
            options = {:method_missing => lambda {super(*args, &block)}, :method_name => #{method_name.inspect}}
            state.call(self, :"#{context_name}", *(args + [options]), &block)
          end
        end_eval
      end
      
      true
    end
    
    # The list of methods that have been defined in this state's context
    def context_methods
      @context.instance_methods.inject({}) do |methods, name|
        methods.merge(name.to_sym => @context.instance_method(name))
      end
    end
    
    # Calls a method defined in this state's context on the given object.  All
    # arguments and any block will be passed into the method defined.
    # 
    # If the method has never been defined for this state, then a NoMethodError
    # will be raised.
    def call(object, method, *args, &block)
      options = args.last.is_a?(Hash) ? args.pop : {}
      options = {:method_name => method}.merge(options)
      state = machine.states.match!(object)
      
      if state == self && object.respond_to?(method)
        object.send(method, *args, &block)
      elsif method_missing = options[:method_missing]
        # Dispatch to the superclass since the object either isn't in this state
        # or this state doesn't handle the method
        method_missing.call
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
    # Configuration options:
    # * <tt>:human_name</tt> - Whether to use the state's human name for the
    #   node's label that gets drawn on the graph
    def draw(graph, options = {})
      node = graph.add_nodes(name ? name.to_s : 'nil',
        :label => description(options),
        :width => '1',
        :height => '1',
        :shape => final? ? 'doublecircle' : 'ellipse'
      )
      
      # Add open arrow for initial state
      graph.add_edges(graph.add_nodes('starting_state', :shape => 'point'), node) if initial?
      
      true
    end
    
    # Generates a nicely formatted description of this state's contents.
    # 
    # For example,
    # 
    #   state = StateMachine::State.new(machine, :parked, :value => 1, :initial => true)
    #   state   # => #<StateMachine::State name=:parked value=1 initial=true context=[]>
    def inspect
      attributes = [[:name, name], [:value, @value], [:initial, initial?]]
      "#<#{self.class} #{attributes.map {|attr, value| "#{attr}=#{value.inspect}"} * ' '}>"
    end
    
    private
      # Should the value be cached after it's evaluated for the first time?
      def cache_value?
        @cache
      end
      
      # Adds a predicate method to the owner class so long as a name has
      # actually been configured for the state
      def add_predicate
        # Checks whether the current value matches this state
        machine.define_helper(:instance, "#{qualified_name}?") do |machine, object|
          machine.states.matches?(object, name)
        end
      end
      
      # Generates the name of the method containing the actual implementation
      def context_name_for(method)
        :"__#{machine.name}_#{name}_#{method}_#{@context.object_id}__"
      end
  end
end
