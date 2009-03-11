require 'state_machine/extensions'
require 'state_machine/assertions'
require 'state_machine/integrations'

require 'state_machine/state'
require 'state_machine/event'
require 'state_machine/callback'
require 'state_machine/node_collection'
require 'state_machine/state_collection'
require 'state_machine/matcher_helpers'

module StateMachine
  # Represents a state machine for a particular attribute.  State machines
  # consist of states, events and a set of transitions that define how the state
  # changes after a particular event is fired.
  # 
  # A state machine will not know all of the possible states for an object unless
  # they are referenced *somewhere* in the state machine definition.  As a result,
  # any unused states should be defined with the +other_states+ or +state+ helper.
  # 
  # == Callbacks
  # 
  # Callbacks are supported for hooking before and after every possible
  # transition in the machine.  Each callback is invoked in the order in which
  # it was defined.  See StateMachine::Machine#before_transition
  # and StateMachine::Machine#after_transition for documentation
  # on how to define new callbacks.
  # 
  # === Canceling callbacks
  # 
  # Callbacks can be canceled by throwing :halt at any point during the
  # callback.  For example,
  # 
  #   ...
  #   throw :halt
  #   ...
  # 
  # If a +before+ callback halts the chain, the associated transition and all
  # later callbacks are canceled.  If an +after+ callback halts the chain,
  # the later callbacks are canceled, but the transition is still successful.
  # 
  # *Note* that if a +before+ callback fails and the bang version of an event
  # was invoked, an exception will be raised instead of returning false.  For
  # example,
  # 
  #   class Vehicle
  #     state_machine :initial => :parked do
  #       before_transition any => :idling, :do => lambda {|vehicle| throw :halt}
  #       ...
  #     end
  #   end
  #   
  #   vehicle = Vehicle.new
  #   vehicle.park        # => false
  #   vehicle.park!       # => StateMachine::InvalidTransition: Cannot transition state via :park from "idling"
  # 
  # == Observers
  # 
  # Observers, in the sense of external classes and *not* Ruby's Observable
  # mechanism, can hook into state machines as well.  Such observers use the
  # same callback api that's used internally.
  # 
  # Below are examples of defining observers for the following state machine:
  # 
  #   class Vehicle
  #     state_machine do
  #       event :park do
  #         transition :idling => :parked
  #       end
  #       ...
  #     end
  #     ...
  #   end
  # 
  # Event/Transition behaviors:
  # 
  #   class VehicleObserver
  #     def self.before_park(vehicle, transition)
  #       logger.info "#{vehicle} instructed to park... state is: #{transition.from}, state will be: #{transition.to}"
  #     end
  #     
  #     def self.after_park(vehicle, transition, result)
  #       logger.info "#{vehicle} instructed to park... state was: #{transition.from}, state is: #{transition.to}"
  #     end
  #     
  #     def self.before_transition(vehicle, transition)
  #       logger.info "#{vehicle} instructed to #{transition.event}... #{transition.attribute} is: #{transition.from}, #{transition.attribute} will be: #{transition.to}"
  #     end
  #     
  #     def self.after_transition(vehicle, transition, result)
  #       logger.info "#{vehicle} instructed to #{transition.event}... #{transition.attribute} was: #{transition.from}, #{transition.attribute} is: #{transition.to}"
  #     end
  #   end
  #   
  #   Vehicle.state_machine do
  #     before_transition :on => :park, :do => VehicleObserver.method(:before_park)
  #     before_transition VehicleObserver.method(:before_transition)
  #     
  #     after_transition :on => :park, :do => VehicleObserver.method(:after_park)
  #     after_transition VehicleObserver.method(:after_transition)
  #   end
  # 
  # One common callback is to record transitions for all models in the system
  # for auditing/debugging purposes.  Below is an example of an observer that
  # can easily automate this process for all models:
  # 
  #   class StateMachineObserver
  #     def self.before_transition(object, transition)
  #       Audit.log_transition(object.attributes)
  #     end
  #   end
  #   
  #   [Vehicle, Switch, Project].each do |klass|
  #     klass.state_machines.each do |machine|
  #       machine.before_transition klass.method(:before_transition)
  #     end
  #   end
  # 
  # Additional observer-like behavior may be exposed by the various integrations
  # available.  See below for more information.
  # 
  # == Overriding instance / class methods
  # 
  # Hooking in behavior to the generated instance / class methods from the
  # state machine, events, and states is very simple because of the way these
  # methods are generated on the class.  Using the class's ancestors, the
  # original generated method can be referred to via +super+.  For example,
  # 
  #   class Vehicle
  #     state_machine do
  #       event :park do
  #         transition :idling => :parked
  #       end
  #     end
  #     
  #     def park(kind = :parallel, *args)
  #       take_deep_breath if kind == :parallel
  #       super(*args)
  #     end
  #     
  #     def take_deep_breath
  #       sleep 3
  #     end
  #   end
  # 
  # In the above example, the +park+ instance method that's generated on the
  # Vehicle class (by the associated event) is overriden with custom behavior
  # that takes an additional argument.  Once this behavior is complete, the
  # original method from the state machine is invoked by simply calling
  # <tt>super(*args)</tt>.
  # 
  # The same technique can be used for +state+, +state_name+, and all other
  # instance *and* class methods on the Vehicle class.
  # 
  # == Integrations
  # 
  # By default, state machines are library-agnostic, meaning that they work
  # on any Ruby class and have no external dependencies.  However, there are
  # certain libraries which expose additional behavior that can be taken
  # advantage of by state machines.
  # 
  # This library is built to work out of the box with a few popular Ruby
  # libraries that allow for additional behavior to provide a cleaner and
  # smoother experience.  This is especially the case for objects backed by a
  # database that may allow for transactions, persistent storage,
  # search/filters, callbacks, etc.
  # 
  # When a state machine is defined for classes using any of the above libraries,
  # it will try to automatically determine the integration to use (Agnostic,
  # ActiveRecord, DataMapper, or Sequel) based on the class definition.  To
  # see how each integration affects the machine's behavior, refer to all
  # constants defined under the StateMachine::Integrations namespace.
  class Machine
    include Assertions
    include MatcherHelpers
    
    class << self
      # The default message to use when invalidating objects that fail to
      # transition when triggering an event
      attr_accessor :default_invalid_message
      
      # Attempts to find or create a state machine for the given class.  For
      # example,
      # 
      #   StateMachine::Machine.find_or_create(Vehicle)
      #   StateMachine::Machine.find_or_create(Vehicle, :initial => :parked)
      #   StateMachine::Machine.find_or_create(Vehicle, :status)
      #   StateMachine::Machine.find_or_create(Vehicle, :status, :initial => :parked)
      # 
      # If a machine of the given name already exists in one of the class's
      # superclasses, then a copy of that machine will be created and stored
      # in the new owner class (the original will remain unchanged).
      def find_or_create(owner_class, *args, &block)
        options = args.last.is_a?(Hash) ? args.pop : {}
        attribute = args.first || :state
        
        # Attempts to find an existing machine
        if owner_class.respond_to?(:state_machines) && machine = owner_class.state_machines[attribute]
          # Create a copy of the state machine if it's being created by a subclass
          unless machine.owner_class == owner_class
            machine = machine.clone
            machine.initial_state = options[:initial] if options.include?(:initial)
            machine.owner_class = owner_class
          end
          
          # Evaluate DSL caller block
          machine.instance_eval(&block) if block_given?
        else
          # No existing machine: create a new one
          machine = new(owner_class, attribute, options, &block)
        end
        
        machine
      end
      
      # Draws the state machines defined in the given classes using GraphViz.
      # The given classes must be a comma-delimited string of class names.
      # 
      # Configuration options:
      # * <tt>:file</tt> - A comma-delimited string of files to load that
      #   contain the state machine definitions to draw
      # * <tt>:path</tt> - The path to write the graph file to
      # * <tt>:format</tt> - The image format to generate the graph in
      # * <tt>:font</tt> - The name of the font to draw state names in
      def draw(class_names, options = {})
        raise ArgumentError, 'At least one class must be specified' unless class_names && class_names.split(',').any?
        
        # Load any files
        if files = options.delete(:file)
          files.split(',').each {|file| require file}
        end
        
        class_names.split(',').each do |class_name|
          # Navigate through the namespace structure to get to the class
          klass = Object
          class_name.split('::').each do |name|
            klass = klass.const_defined?(name) ? klass.const_get(name) : klass.const_missing(name)
          end
          
          # Draw each of the class's state machines
          klass.state_machines.each do |name, machine|
            machine.draw(options)
          end
        end
      end
    end
    
    # Set defaults
    self.default_invalid_message = 'cannot be transitioned via :%s from :%s'
    
    # The class that the machine is defined in
    attr_accessor :owner_class
    
    # The attribute for which the machine is being defined
    attr_reader :attribute
    
    # The events that trigger transitions.  These are sorted, by default, in the
    # order in which they were defined.
    attr_reader :events
    
    # A list of all of the states known to this state machine.  This will pull
    # states from the following sources:
    # * Initial state
    # * State behaviors
    # * Event transitions (:to, :from, and :except_from options)
    # * Transition callbacks (:to, :from, :except_to, and :except_from options)
    # * Unreferenced states (using +other_states+ helper)
    # 
    # These are sorted, by default, in the order in which they were referenced.
    attr_reader :states
    
    # The callbacks to invoke before/after a transition is performed
    # 
    # Maps :before => callbacks and :after => callbacks
    attr_reader :callbacks
    
    # The action to invoke when an object transitions
    attr_reader :action
    
    # An identifier that forces all methods (including state predicates and
    # event methods) to be generated with the value prefixed or suffixed,
    # depending on the context.
    attr_reader :namespace
    
    # Creates a new state machine for the given attribute
    def initialize(owner_class, *args, &block)
      options = args.last.is_a?(Hash) ? args.pop : {}
      assert_valid_keys(options, :initial, :action, :plural, :namespace, :integration, :invalid_message)
      
      # Set machine configuration
      @attribute = args.first || :state
      @events = NodeCollection.new
      @states = StateCollection.new
      @callbacks = {:before => [], :after => []}
      @namespace = options[:namespace]
      @invalid_message = options[:invalid_message]
      
      self.owner_class = owner_class
      self.initial_state = options[:initial]
      
      # Find an integration that matches this machine's owner class
      if integration = options[:integration] ? StateMachine::Integrations.find(options[:integration]) : StateMachine::Integrations.match(owner_class)
        extend integration
      end
      
      # Set integration-specific configurations
      @action = options.include?(:action) ? options[:action] : default_action
      define_attribute_helpers
      define_scopes(options[:plural])
      
      # Call after hook for integration-specific extensions
      after_initialize
      
      # Evaluate DSL caller block
      instance_eval(&block) if block_given?
    end
    
    # Creates a copy of this machine in addition to copies of each associated
    # event/states/callback, so that the modifications to those collections do
    # not affect the original machine.
    def initialize_copy(orig) #:nodoc:
      super
      
      @events = @events.dup
      @events.machine = self
      @states = @states.dup
      @states.machine = self
      @callbacks = {:before => @callbacks[:before].dup, :after => @callbacks[:after].dup}
    end
    
    # Sets the class which is the owner of this state machine.  Any methods
    # generated by states, events, or other parts of the machine will be defined
    # on the given owner class.
    def owner_class=(klass)
      @owner_class = klass
      
      # Add class-/instance-level methods to the owner class for state initialization
      owner_class.class_eval do
        extend StateMachine::ClassMethods
        include StateMachine::InstanceMethods
      end unless owner_class.included_modules.include?(StateMachine::InstanceMethods)
      
      # Create modules for extending the class with state/event-specific methods
      class_helper_module = @class_helper_module = Module.new
      instance_helper_module = @instance_helper_module = Module.new
      owner_class.class_eval do
        extend class_helper_module
        include instance_helper_module
      end
      
      # Record this machine as matched to the attribute in the current owner
      # class.  This will override any machines mapped to the same attribute
      # in any superclasses.
      owner_class.state_machines[attribute] = self
    end
    
    # Sets the initial state of the machine.  This can be either the static name
    # of a state or a lambda block which determines the initial state at
    # creation time.
    def initial_state=(new_initial_state)
      @initial_state = new_initial_state
      add_states([@initial_state]) unless @initial_state.is_a?(Proc)
      
      # Update all states to reflect the new initial state
      states.each {|state| state.initial = (state.name == @initial_state)}
    end
    
    # Defines a new instance method with the given name on the machine's owner
    # class.  If the method is already defined in the class, then this will not
    # override it.
    # 
    # Not that in order for inheritance to work properly within state machines,
    # any states/events/etc. must be referred to from the current state machine
    # associated with the executing class.
    # 
    # Example:
    # 
    #   attribute = machine.attribute
    #   machine.define_instance_method(:parked?) do |machine, object|
    #     machine.state?(object, :parked)
    #   end
    def define_instance_method(method, &block)
      attribute = self.attribute
      
      @instance_helper_module.class_eval do
        define_method(method) do |*args|
          block.call(self.class.state_machines[attribute], self, *args)
        end
      end
    end
    attr_reader :instance_helper_module
    
    # Defines a new class method with the given name on the machine's owner
    # class.  If the method is already defined in the class, then this will not
    # override it.
    # 
    # Not that in order for inheritance to work properly within state machines,
    # any states/events/etc. must be referred to from the current state machine
    # associated with the executing class.
    # 
    # Example:
    # 
    #   machine.define_class_method(:states) do |machine, klass|
    #     machine.states.keys
    #   end
    def define_class_method(method, &block)
      attribute = self.attribute
      
      @class_helper_module.class_eval do
        define_method(method) do |*args|
          block.call(self.state_machines[attribute], self, *args)
        end
      end
    end
    
    # Gets the initial state of the machine for the given object. If a dynamic
    # initial state was configured for this machine, then the object will be
    # passed into the lambda block to help determine the actual state.
    # 
    # == Examples
    # 
    # With a static initial state:
    # 
    #   class Vehicle
    #     state_machine :initial => :parked do
    #       ...
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new
    #   Vehicle.state_machines[:state].initial_state(vehicle)   # => #<StateMachine::State name=:parked value="parked" initial=true>
    # 
    # With a dynamic initial state:
    # 
    #   class Vehicle
    #     attr_accessor :force_idle
    #     
    #     state_machine :initial => lambda {|vehicle| vehicle.force_idle ? :idling : :parked} do
    #       ...
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new
    #   
    #   vehicle.force_idle = true
    #   Vehicle.state_machines[:state].initial_state(vehicle)   # => #<StateMachine::State name=:idling value="idling" initial=false>
    #   
    #   vehicle.force_idle = false
    #   Vehicle.state_machines[:state].initial_state(vehicle)   # => #<StateMachine::State name=:parked value="parked" initial=false>
    def initial_state(object)
      states.fetch(@initial_state.is_a?(Proc) ? @initial_state.call(object) : @initial_state)
    end
    
    # Customizes the definition of one or more states in the machine.
    # 
    # Configuration options:
    # * <tt>:value</tt> - The actual value to store when an object transitions
    #   to the state.  Default is the name (stringified).
    # * <tt>:if</tt> - Determines whether an object's value matches the state
    #   (e.g. :value => lambda {Time.now}, :if => lambda {|state| !state.nil?}).
    #   By default, the configured value is matched.
    # 
    # == Customizing the stored value
    # 
    # Whenever a state is automatically discovered in the state machine, its
    # default value is assumed to be the stringified version of the name.  For
    # example,
    # 
    #   class Vehicle
    #     state_machine :initial => :parked do
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #   end
    # 
    # In the above state machine, there are two states automatically discovered:
    # :parked and :idling.  These states, by default, will store their stringified
    # equivalents when an object moves into that states (e.g. "parked" / "idling").
    # 
    # For legacy systems or when tying state machines into existing frameworks,
    # it's oftentimes necessary to need to store a different value for a state
    # than the default.  In order to continue taking advantage of an expressive
    # state machine and helper methods, every defined state can be re-configured
    # with a custom stored value.  For example,
    # 
    #   class Vehicle
    #     state_machine :initial => :parked do
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #       
    #       state :idling, :value => 'IDLING'
    #       state :parked, :value => 'PARKED
    #     end
    #   end
    # 
    # This is also useful if being used in association with a database and,
    # instead of storing the state name in a column, you want to store the
    # state's foreign key:
    # 
    #   class VehicleState < ActiveRecord::Base
    #   end
    #   
    #   class Vehicle < ActiveRecord::Base
    #     state_machine :state_id, :initial => :parked do
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #       
    #       states.each {|state| self.state(state.name, :value => VehicleState.find_by_name(state.name.to_s).id)}
    #     end
    #   end
    # 
    # In the above example, each known state is configured to store it's
    # associated database id in the +state_id+ attribute.
    # 
    # === Dynamic values
    # 
    # In addition to customizing states with other value types, lambda blocks
    # can also be specified to allow for a state's value to be determined
    # dynamically at runtime.  For example,
    # 
    #   class Vehicle
    #     state_machine :purchased_at, :initial => :available do
    #       event :purchase do
    #         transition all => :purchased
    #       end
    #       
    #       event :restock do
    #         transition all => :available
    #       end
    #       
    #       state :available, :value => nil
    #       state :purchased, :if => lambda {|value| !value.nil?}, :value => lambda {Time.now}
    #     end
    #   end
    # 
    # In the above definition, the <tt>:purchased</tt> state is customized with
    # both a dynamic value *and* a value matcher.
    # 
    # When an object transitions to the purchased state, the value's lambda
    # block will be called.  This will get the current time and store it in the
    # object's +purchased_at+ attribute.
    # 
    # *Note* that the custom matcher is very important here.  Since there's no
    # way for the state machine to figure out an object's state when it's set to
    # a runtime value, it must be explicitly defined.  If the <tt>:if</tt> option
    # were not configured for the state, then an ArgumentError exception would
    # be raised at runtime, indicating that the state machine could not figure
    # out what the current state of the object was.
    # 
    # == Behaviors
    # 
    # Behaviors define a series of methods to mixin with objects when the current
    # state matches the given one(s).  This allows instance methods to behave
    # a specific way depending on what the value of the object's state is.
    # 
    # For example,
    # 
    #   class Vehicle
    #     attr_accessor :driver
    #     attr_accessor :passenger
    #     
    #     state_machine :initial => :parked do
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #       
    #       state :parked do
    #         def speed
    #           0
    #         end
    #         
    #         def rotate_driver
    #           driver = self.driver
    #           self.driver = passenger
    #           self.passenger = driver
    #           true
    #         end
    #       end
    #       
    #       state :idling, :first_gear do
    #         def speed
    #           20
    #         end
    #         
    #         def rotate_driver
    #           self.state = 'parked'
    #           rotate_driver
    #         end
    #       end
    #       
    #       other_states :backing_up
    #     end
    #   end
    # 
    # In the above example, there are two dynamic behaviors defined for the
    # class:
    # * +speed+
    # * +rotate_driver+
    # 
    # Each of these behaviors are instance methods on the Vehicle class.  However,
    # which method actually gets invoked is based on the current state of the
    # object.  Using the above class as the example:
    # 
    #   vehicle = Vehicle.new
    #   vehicle.driver = 'John'
    #   vehicle.passenger = 'Jane'
    #   
    #   # Behaviors in the "parked" state
    #   vehicle.state             # => "parked"
    #   vehicle.speed             # => 0
    #   vehicle.rotate_driver     # => true
    #   vehicle.driver            # => "Jane"
    #   vehicle.passenger         # => "John"
    #   
    #   vehicle.ignite            # => true
    #   
    #   # Behaviors in the "idling" state
    #   vehicle.state             # => "idling"
    #   vehicle.speed             # => 20
    #   vehicle.rotate_driver     # => true
    #   vehicle.driver            # => "John"
    #   vehicle.passenger         # => "Jane"
    #   vehicle.state             # => "parked"
    # 
    # As can be seen, both the +speed+ and +rotate_driver+ instance method
    # implementations changed how they behave based on what the current state
    # of the vehicle was.
    # 
    # === Invalid behaviors
    # 
    # If a specific behavior has not been defined for a state, then a
    # NoMethodError exception will be raised, indicating that that method would
    # not normally exist for an object with that state.
    # 
    # Using the example from before:
    # 
    #   vehicle = Vehicle.new
    #   vehicle.state = 'backing_up'
    #   vehicle.speed               # => NoMethodError: undefined method 'speed' for #<Vehicle:0xb7d296ac> in state "backing_up"
    # 
    # == State-aware class methods
    # 
    # In addition to defining scopes for instance methods that are state-aware,
    # the same can be done for certain types of class methods.
    # 
    # Some libraries have support for class-level methods that only run certain
    # behaviors based on a conditions hash passed in.  For example:
    # 
    #   class Vehicle < ActiveRecord::Base
    #     state_machine do
    #       ...
    #       state :first_gear, :second_gear, :third_gear do
    #         validates_presence_of   :speed
    #         validates_inclusion_of  :speed, :in => 0..25, :if => :in_school_zone?
    #       end
    #     end
    #   end
    # 
    # In the above ActiveRecord model, two validations have been defined which
    # will *only* run when the Vehicle object is in one of the three states:
    # +first_gear+, +second_gear+, or +third_gear.  Notice, also, that if/unless
    # conditions can continue to be used.
    # 
    # This functionality is not library-specific and can work for any class-level
    # method that is defined like so:
    # 
    #   def validates_presence_of(attribute, options = {})
    #     ...
    #   end
    # 
    # The minimum requirement is that the last argument in the method be an
    # options hash which contains at least <tt>:if</tt> condition support.
    def state(*names, &block)
      options = names.last.is_a?(Hash) ? names.pop : {}
      assert_valid_keys(options, :value, :if)
      
      states = add_states(names)
      states.each do |state|
        if options.include?(:value)
          state.value = options[:value]
          self.states.update(state)
        end
        
        state.matcher = options[:if] if options.include?(:if)
        state.context(&block) if block_given?
      end
      
      states.length == 1 ? states.first : states
    end
    alias_method :other_states, :state
    
    # Determines whether the given object is in a specific state.  If the
    # object's current value doesn't match the state, then this will return
    # false, otherwise true.  If the given state is unknown, then an ArgumentError
    # will be raised.
    # 
    # == Examples
    # 
    #   class Vehicle
    #     state_machine :initial => :parked do
    #       other_states :idling
    #     end
    #   end
    #   
    #   machine = Vehicle.state_machines[:state]
    #   vehicle = Vehicle.new               # => #<Vehicle:0xb7c464b0 @state="parked">
    #   
    #   machine.state?(vehicle, :parked)    # => true
    #   machine.state?(vehicle, :idling)    # => false
    #   machine.state?(vehicle, :invalid)   # => ArgumentError: :invalid is an invalid key for :name index
    def state?(object, name)
      states.fetch(name).matches?(object.send(attribute))
    end
    
    # Determines the current state of the given object as configured by this
    # state machine.  This will attempt to find a known state that matches
    # the value of the attribute on the object.  If no state is found, then
    # an ArgumentError will be raised.
    # 
    # == Examples
    # 
    #   class Vehicle
    #     state_machine :initial => :parked do
    #       other_states :idling
    #     end
    #   end
    #   
    #   machine = Vehicle.state_machines[:state]
    #   
    #   vehicle = Vehicle.new         # => #<Vehicle:0xb7c464b0 @state="parked">
    #   machine.state_for(vehicle)    # => #<StateMachine::State name=:parked value="parked" initial=true>
    #   
    #   vehicle.state = 'idling'
    #   machine.state_for(vehicle)    # => #<StateMachine::State name=:idling value="idling" initial=true>
    #   
    #   vehicle.state = 'invalid'
    #   machine.state_for(vehicle)    # => ArgumentError: "invalid" is not a known state value
    def state_for(object)
      value = object.send(attribute)
      state = states[value, :value] || states.detect {|state| state.matches?(value)}
      raise ArgumentError, "#{value.inspect} is not a known #{attribute} value" unless state
      
      state
    end
    
    # Defines one or more events for the machine and the transitions that can
    # be performed when those events are run.
    # 
    # This method is also aliased as +on+ for improved compatibility with
    # using a domain-specific language.
    # 
    # == Instance methods
    # 
    # The following instance methods are generated when a new event is defined
    # (the "park" event is used as an example):
    # * <tt>can_park?</tt> - Checks whether the "park" event can be fired given
    #   the current state of the object.
    # * <tt>next_park_transition</tt> -  Gets the next transition that would be
    #   performed if the "park" event were to be fired now on the object or nil
    #   if no transitions can be performed.
    # * <tt>park(run_action = true)</tt> - Fires the "park" event, transitioning
    #   from the current state to the next valid state.
    # * <tt>park!(run_action = true)</tt> - Fires the "park" event, transitioning
    #   from the current state to the next valid state.  If the transition fails,
    #   then a StateMachine::InvalidTransition error will be raised.
    # 
    # With a namespace of "car", the above names map to the following methods:
    # * <tt>can_park_car?</tt>
    # * <tt>next_park_car_transition</tt>
    # * <tt>park_car</tt>
    # * <tt>park_car!</tt>
    # 
    # == Defining transitions
    # 
    # +event+ requires a block which allows you to define the possible
    # transitions that can happen as a result of that event.  For example,
    # 
    #   event :park, :stop do
    #     transition :idling => :parked
    #   end
    #   
    #   event :first_gear do
    #     transition :parked => :first_gear, :if => :seatbelt_on?
    #   end
    # 
    # See StateMachine::Event#transition for more information on
    # the possible options that can be passed in.
    # 
    # *Note* that this block is executed within the context of the actual event
    # object.  As a result, you will not be able to reference any class methods
    # on the model without referencing the class itself.  For example,
    # 
    #   class Vehicle
    #     def self.safe_states
    #       [:parked, :idling, :stalled]
    #     end
    #     
    #     state_machine do
    #       event :park do
    #         transition Vehicle.safe_states => :parked
    #       end
    #     end
    #   end 
    # 
    # == Example
    # 
    #   class Vehicle
    #     state_machine do
    #       # The park, stop, and halt events will all share the given transitions
    #       event :park, :stop, :halt do
    #         transition [:idling, :backing_up] => :parked
    #       end
    #       
    #       event :stop do
    #         transition :first_gear => :idling
    #       end
    #       
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #   end
    def event(*names, &block)
      events = names.collect do |name|
        unless event = self.events[name]
          self.events << event = Event.new(self, name)
        end
        
        if block_given?
          event.instance_eval(&block)
          add_states(event.known_states)
        end
        
        event
      end
      
      events.length == 1 ? events.first : events
    end
    alias_method :on, :event
    
    # Creates a callback that will be invoked *before* a transition is
    # performed so long as the given requirements match the transition.
    # 
    # == The callback
    # 
    # Callbacks must be defined as either the only argument, in the :do option,
    # or as a block.  For example,
    # 
    #   class Vehicle
    #     state_machine do
    #       before_transition :set_alarm
    #       before_transition all => :parked :do => :set_alarm
    #       before_transition all => :parked do |vehicle, transition|
    #         vehicle.set_alarm
    #       end
    #       ...
    #     end
    #   end
    # 
    # == State requirements
    # 
    # Callbacks can require that the machine be transitioning from and to
    # specific states.  These requirements use a Hash syntax to map beginning
    # states to ending states.  For example,
    # 
    #   before_transition :parked => :idling, :idling => :first_gear, :do => :set_alarm
    # 
    # In this case, the +set_alarm+ callback will only be called if the machine
    # is transitioning from +parked+ to +idling+ or from +idling+ to +parked+.
    # 
    # To help define state requirements, a set of helpers are available for
    # slightly more complex matching:
    # * <tt>all</tt> - Matches every state/event in the machine
    # * <tt>all - [:parked, :idling, ...]</tt> - Matches every state/event except those specified
    # * <tt>any</tt> - An alias for +all+ (matches every state/event in the machine)
    # * <tt>same</tt> - Matches the same state being transitioned from
    # 
    # See StateMachine::MatcherHelpers for more information.
    # 
    # Examples:
    # 
    #   before_transition :parked => [:idling, :first_gear], :do => ...     # Matches from parked to idling or first_gear
    #   before_transition all - [:parked, :idling] => :idling, :do => ...   # Matches from every state except parked and idling to idling
    #   before_transition all => :parked, :do => ...                        # Matches all states to parked
    #   before_transition any => same, :do => ...                           # Matches every loopback
    # 
    # == Event requirements
    # 
    # In addition to state requirements, an event requirement can be defined so
    # that the callback is only invoked on specific events using the +on+
    # option.  This can also use the same matcher helpers as the state
    # requirements.
    # 
    # Examples:
    # 
    #   before_transition :on => :ignite, :do => ...                        # Matches only on ignite
    #   before_transition :on => all - :ignite, :do => ...                  # Matches on every event except ignite
    #   before_transition :parked => :idling, :on => :ignite, :do => ...    # Matches from parked to idling on ignite
    # 
    # == Verbose Requirements
    # 
    # Requirements can also be defined using verbose options rather than the
    # implicit Hash syntax and helper methods described above.
    # 
    # Configuration options:
    # * <tt>:from</tt> - One or more states being transitioned from.  If none
    #   are specified, then all states will match.
    # * <tt>:to</tt> - One or more states being transitioned to.  If none are
    #   specified, then all states will match.
    # * <tt>:on</tt> - One or more events that fired the transition.  If none
    #   are specified, then all events will match.
    # * <tt>:except_from</tt> - One or more states *not* being transitioned from
    # * <tt>:except_to</tt> - One more states *not* being transitioned to
    # * <tt>:except_on</tt> - One or more events that *did not* fire the transition
    # 
    # Examples:
    # 
    #   before_transition :from => :ignite, :to => :idling, :on => :park, :do => ...
    #   before_transition :except_from => :ignite, :except_to => :idling, :except_on => :park, :do => ...
    # 
    # == Conditions
    # 
    # In addition to the state/event requirements, a condition can also be
    # defined to help determine whether the callback should be invoked.
    # 
    # Configuration options:
    # * <tt>:if</tt> - A method, proc or string to call to determine if the
    #   callback should occur (e.g. :if => :allow_callbacks, or
    #   :if => lambda {|user| user.signup_step > 2}). The method, proc or string
    #   should return or evaluate to a true or false value. 
    # * <tt>:unless</tt> - A method, proc or string to call to determine if the
    #   callback should not occur (e.g. :unless => :skip_callbacks, or
    #   :unless => lambda {|user| user.signup_step <= 2}). The method, proc or
    #   string should return or evaluate to a true or false value. 
    # 
    # Examples:
    # 
    #   before_transition :parked => :idling, :if => :moving?
    #   before_transition :on => :ignite, :unless => :seatbelt_on?
    # 
    # === Accessing the transition
    # 
    # In addition to passing the object being transitioned, the actual
    # transition describing the context (e.g. event, from, to) can be accessed
    # as well.  This additional argument is only passed if the callback allows
    # for it.
    # 
    # For example,
    # 
    #   class Vehicle
    #     # Only specifies one parameter (the object being transitioned)
    #     before_transition :to => :parked, :do => lambda {|vehicle| vehicle.set_alarm}
    #     
    #     # Specifies 2 parameters (object being transitioned and actual transition)
    #     before_transition :to => :parked, :do => lambda {|vehicle, transition| vehicle.set_alarm(transition)}
    #   end
    # 
    # *Note* that the object in the callback will only be passed in as an
    # argument if callbacks are configured to *not* be bound to the object
    # involved.  This is the default and may change on a per-integration basis.
    # 
    # See StateMachine::Transition for more information about the
    # attributes available on the transition.
    # 
    # == Examples
    # 
    # Below is an example of a class with one state machine and various types
    # of +before+ transitions defined for it:
    # 
    #   class Vehicle
    #     state_machine do
    #       # Before all transitions
    #       before_transition :update_dashboard
    #       
    #       # Before specific transition:
    #       before_transition [:first_gear, :idling] => :parked, :on => :park, :do => :take_off_seatbelt
    #       
    #       # With conditional callback:
    #       before_transition :to => :parked, :do => :take_off_seatbelt, :if => :seatbelt_on?
    #       
    #       # Using helpers:
    #       before_transition all - :stalled => same, :on => any - :crash, :do => :update_dashboard
    #       ...
    #     end
    #   end
    # 
    # As can be seen, any number of transitions can be created using various
    # combinations of configuration options.
    def before_transition(options = {}, &block)
      add_callback(:before, options.is_a?(Hash) ? options : {:do => options}, &block)
    end
    
    # Creates a callback that will be invoked *after* a transition is
    # performed so long as the given requirements match the transition.
    # 
    # See +before_transition+ for a description of the possible configurations
    # for defining callbacks.
    def after_transition(options = {}, &block)
      add_callback(:after, options.is_a?(Hash) ? options : {:do => options}, &block)
    end
    
    # Marks the given object as invalid after failing to transition via the
    # given event.
    # 
    # By default, this is a no-op.
    def invalidate(object, event)
    end
    
    # Resets an errors previously added when invalidating the given object
    # 
    # By default, this is a no-op.
    def reset(object)
    end
    
    # Runs a transaction, rolling back any changes if the yielded block fails.
    # 
    # This is only applicable to integrations that involve databases.  By
    # default, this will not run any transactions, since the changes aren't
    # taking place within the context of a database.
    def within_transaction(object)
      yield
    end
    
    # Draws a directed graph of the machine for visualizing the various events,
    # states, and their transitions.
    # 
    # This requires both the Ruby graphviz gem and the graphviz library be
    # installed on the system.
    # 
    # Configuration options:
    # * <tt>:name</tt> - The name of the file to write to (without the file extension).
    #   Default is "#{owner_class.name}_#{attribute}"
    # * <tt>:path</tt> - The path to write the graph file to.  Default is the
    #   current directory (".").
    # * <tt>:format</tt> - The image format to generate the graph in.
    #   Default is "png'.
    # * <tt>:font</tt> - The name of the font to draw state names in.
    #   Default is "Arial".
    # * <tt>:orientation</tt> - The direction of the graph ("portrait" or
    #   "landscape").  Default is "portrait".
    # * <tt>:output</tt> - Whether to generate the output of the graph
    def draw(options = {})
      options = {
        :name => "#{owner_class.name}_#{attribute}",
        :path => '.',
        :format => 'png',
        :font => 'Arial',
        :orientation => 'portrait',
        :output => true
      }.merge(options)
      assert_valid_keys(options, :name, :path, :format, :font, :orientation, :output)
      
      begin
        # Load the graphviz library
        require 'rubygems'
        require 'graphviz'
        
        graph = GraphViz.new('G',
          :output => options[:format],
          :file => File.join(options[:path], "#{options[:name]}.#{options[:format]}"),
          :rankdir => options[:orientation] == 'landscape' ? 'LR' : 'TB'
        )
        
        # Add nodes
        states.by_priority.each do |state|
          node = state.draw(graph)
          node.fontname = options[:font]
        end
        
        # Add edges
        events.each do |event|
          edges = event.draw(graph)
          edges.each {|edge| edge.fontname = options[:font]}
        end
        
        # Generate the graph
        graph.output if options[:output]
        graph
      rescue LoadError
        $stderr.puts 'Cannot draw the machine. `gem install ruby-graphviz` and try again.'
        false
      end
    end
    
    protected
      # Runs additional initialization hooks.  By default, this is a no-op.
      def after_initialize
      end
      
      # Gets the default action that should be invoked when performing a
      # transition on the attribute for this machine.  This may change
      # depending on the configured integration for the owner class.
      def default_action
      end
      
      # Adds helper methods for interacting with this state machine's attribute,
      # including reader, writer, and predicate methods
      def define_attribute_helpers
        define_attribute_accessor
        define_attribute_predicate
        
        attribute = self.attribute
        
        # Gets the state name for the current value
        define_instance_method("#{attribute}_name") do |machine, object|
          machine.state_for(object).name
        end
      end
      
      # Adds reader/writer methods for accessing the attribute
      def define_attribute_accessor
        attribute = self.attribute
        
        @instance_helper_module.class_eval do
          attr_reader attribute
          attr_writer attribute
        end
      end
      
      # Adds predicate method to the owner class for determining the name of the
      # current state
      def define_attribute_predicate
        attribute = self.attribute
        
        # Checks whether the current state is a given value
        define_instance_method("#{attribute}?") do |machine, object, state|
          machine.state?(object, state)
        end
      end
      
      # Defines the with/without scope helpers for this attribute.  Both the
      # singular and plural versions of the attribute are defined for each
      # scope helper.  A custom plural can be specified if it cannot be
      # automatically determined by either calling +pluralize+ on the attribute
      # name or adding an "s" to the end of the name.
      def define_scopes(custom_plural = nil)
        attribute = self.attribute
        plural = custom_plural || (attribute.to_s.respond_to?(:pluralize) ? attribute.to_s.pluralize : "#{attribute}s")
        
        [attribute, plural].uniq.each do |name|
          [:with, :without].each do |kind|
            method = "#{kind}_#{name}"
            
            if scope = send("create_#{kind}_scope", method)
              # Converts state names to their corresponding values so that they
              # can be looked up properly
              define_class_method(method) do |machine, klass, *states|
                machine_states = machine.states
                values = states.flatten.map {|state| machine_states.fetch(state).value}
                
                # Invoke the original scope implementation
                scope.call(klass, values)
              end
            end
          end
        end
      end
      
      # Creates a scope for finding objects *with* a particular value or values
      # for the attribute.
      # 
      # This is only applicable to specific integrations.
      def create_with_scope(name)
      end
      
      # Creates a scope for finding objects *without* a particular value or
      # values for the attribute.
      # 
      # This is only applicable to specific integrations.
      def create_without_scope(name)
      end
      
      # Adds a new transition callback of the given type.
      def add_callback(type, options, &block)
        callbacks[type] << callback = Callback.new(options, &block)
        add_states(callback.known_states)
        callback
      end
      
      # Tracks the given set of states in the list of all known states for
      # this machine
      def add_states(new_states)
        new_states.collect do |new_state|
          unless state = states[new_state]
            states << state = State.new(self, new_state)
          end
          
          state
        end
      end
      
      # Generates the message to use when invalidating the given object after
      # failing to transition on a specific event
      def invalid_message(object, event)
        (@invalid_message || self.class.default_invalid_message) % [event.name, state_for(object).name]
      end
  end
end
