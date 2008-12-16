require 'state_machine/extensions'
require 'state_machine/event'
require 'state_machine/callback'
require 'state_machine/assertions'

# Load each available integration
Dir["#{File.dirname(__FILE__)}/integrations/*.rb"].sort.each do |path|
  require "state_machine/integrations/#{File.basename(path)}"
end

module StateMachine
  # Represents a state machine for a particular attribute.  State machines
  # consist of events and a set of transitions that define how the state
  # changes after a particular event is fired.
  # 
  # A state machine may not necessarily know all of the possible states for
  # an object since they can be any arbitrary value.  As a result, anything
  # that relies on a list of all possible states should keep in mind that if
  # a state has not been referenced *anywhere* in the state machine definition,
  # then it will *not* be a known state unless the +other_states+ helper is used.
  # 
  # == State values
  # 
  # While strings are the most common object type used for setting values on
  # the state of the machine, there are no restrictions on what can be used.
  # This means that symbols, integers, dates/times, etc. can all be used.
  # 
  # With string states:
  # 
  #   class Vehicle
  #     state_machine :initial => 'parked' do
  #       event :ignite do
  #         transition :to => 'idling', :from => 'parked'
  #       end
  #     end
  #   end
  # 
  # With symbolic states:
  # 
  #   class Vehicle
  #     state_machine :initial => :parked do
  #       event :ignite do
  #         transition :to => :idling, :from => :parked
  #       end
  #     end
  #   end
  # 
  # With time states:
  # 
  #   class Switch
  #     state_machine :activated_at
  #       before_transition :to => nil, :do => lambda {...}
  #       
  #       event :activate do
  #         transition :to => lambda {Time.now}
  #       end
  #       
  #       event :deactivate do
  #         transition :to => nil
  #       end
  #     end
  #   end
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
  #     state_machine, :initial => 'parked' do
  #       before_transition :to => 'idling', :do => lambda {|vehicle| throw :halt}
  #       ...
  #     end
  #   end
  #   
  #   vehicle = Vehicle.new
  #   vehicle.park        # => false
  #   vehicle.park!       # => StateMachine::InvalidTransition: Cannot transition via :park from "idling"
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
  #       event :ignite do
  #         transition :to => 'idling', :from => 'parked'
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
  # Additional observer-like behavior may be exposed by the various
  # integrations available.  See below for more information.
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
    
    # The class that the machine is defined in
    attr_reader :owner_class
    
    # The attribute for which the machine is being defined
    attr_reader :attribute
    
    # The initial state that the machine will be in when an object is created
    attr_reader :initial_state
    
    # The events that trigger transitions
    attr_reader :events
    
    # A list of all of the states known to this state machine.  This will pull
    # state names from the following sources:
    # * Initial state
    # * Event transitions (:to, :from, :except_to, and :except_from options)
    # * Transition callbacks (:to, :from, :except_to, and :except_from options)
    # * Unreferenced states (using +other_states+ helper)
    attr_reader :states
    
    # The callbacks to invoke before/after a transition is performed
    attr_reader :callbacks
    
    # The action to invoke when an object transitions
    attr_reader :action
    
    class << self
      # Attempts to find or create a state machine for the given class.  For
      # example,
      # 
      #   StateMachine::Machine.find_or_create(Switch)
      #   StateMachine::Machine.find_or_create(Switch, :initial => 'off')
      #   StateMachine::Machine.find_or_create(Switch, 'status')
      #   StateMachine::Machine.find_or_create(Switch, 'status', :initial => 'off')
      # 
      # If a machine of the given name already exists in one of the class's
      # superclasses, then a copy of that machine will be created and stored
      # in the new owner class (the original will remain unchanged).
      def find_or_create(owner_class, *args, &block)
        options = args.last.is_a?(Hash) ? args.pop : {}
        attribute = (args.first || 'state').to_s
        
        # Attempts to find an existing machine
        if owner_class.respond_to?(:state_machines) && machine = owner_class.state_machines[attribute]
          machine = machine.within_context(owner_class, options) unless machine.owner_class == owner_class
          
          # Evaluate caller block for DSL
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
      # * +file+ - A comma-delimited string of files to load that contain the state machine definitions to draw
      # * +path+ - The path to write the graph file to
      # * +format+ - The image format to generate the graph in
      # * +font+ - The name of the font to draw state names in
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
          klass.state_machines.values.each do |machine|
            machine.draw(options)
          end
        end
      end
    end
    
    # Creates a new state machine for the given attribute
    def initialize(owner_class, *args, &block)
      options = args.last.is_a?(Hash) ? args.pop : {}
      assert_valid_keys(options, :initial, :action, :plural, :integration)
      
      # Set machine configuration
      @attribute = (args.first || 'state').to_s
      @events = {}
      @states = []
      @callbacks = {:before => [], :after => []}
      @action = options[:action]
      
      # Add class-/instance-level methods to the owner class for state initialization
      owner_class.class_eval do
        extend StateMachine::ClassMethods
        include StateMachine::InstanceMethods
      end unless owner_class.included_modules.include?(StateMachine::InstanceMethods)
      
      # Initialize the class context of the machine
      set_context(owner_class, :initial => options[:initial], :integration => options[:integration], &block)
      
      # Set integration-specific configurations
      @action ||= default_action unless options.include?(:action)
      define_attribute_accessor
      define_scopes(options[:plural])
      
      # Call after hook for integration-specific extensions
      after_initialize
      
      # Evaluate caller block for DSL
      instance_eval(&block) if block_given?
    end
    
    # Creates a copy of this machine in addition to copies of each associated
    # event, so that the list of transitions for each event don't conflict
    # with different machines
    def initialize_copy(orig) #:nodoc:
      super
      
      @events = @events.inject({}) do |events, (name, event)|
        event = event.dup
        event.machine = self
        events[name] = event
        events
      end
      @states = @states.dup
      @callbacks = {:before => @callbacks[:before].dup, :after => @callbacks[:after].dup}
    end
    
    # Creates a copy of this machine within the context of the given class.
    # This should be used for inheritance support of state machines.
    def within_context(owner_class, options = {}, &block) #:nodoc:
      machine = dup
      machine.set_context(owner_class, {:integration => @integration}.merge(options))
      machine
    end
    
    # Changes the context of this machine to the given class so that new
    # events and transitions are created in the proper context.
    # 
    # Configuration options:
    # * +initial+ - The initial value to set the attribute to
    # * +integration+ - The name of the integration for extending this machine with library-specific behavior
    # 
    # All other configuration options for the machine can only be set on
    # creation.
    def set_context(owner_class, options = {}) #:nodoc:
      assert_valid_keys(options, :initial, :integration)
      
      @owner_class = owner_class
      @initial_state = options[:initial] if options[:initial]
      add_states([@initial_state])
      
      # Find an integration that can be used for implementing various parts
      # of the state machine that may behave differently in different libraries
      if @integration = options[:integration] || StateMachine::Integrations.constants.find {|name| StateMachine::Integrations.const_get(name).matches?(owner_class)}
        extend StateMachine::Integrations.const_get(@integration.to_s.gsub(/(?:^|_)(.)/) {$1.upcase})
      end
      
      # Record this machine as matched to the attribute in the current owner
      # class.  This will override any machines mapped to the same attribute
      # in any superclasses.
      owner_class.state_machines[attribute] = self
    end
    
    # Gets the initial state of the machine for the given object. If a dynamic
    # initial state was configured for this machine, then the object will be
    # passed into the lambda block to help determine the actual value of the
    # initial state.
    # 
    # == Examples
    # 
    # With a static initial state:
    # 
    #   class Vehicle
    #     state_machine :initial => 'parked' do
    #       ...
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new
    #   Vehicle.state_machines['state'].initial_state(vehicle)   # => "parked"
    # 
    # With a dynamic initial state:
    # 
    #   class Vehicle
    #     attr_accessor :force_idle
    #     
    #     state_machine :initial => lambda {|vehicle| vehicle.force_idle ? 'idling' : 'parked'} do
    #       ...
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new
    #   
    #   vehicle.force_idle = true
    #   Vehicle.state_machines['state'].initial_state(vehicle)   # => "idling"
    #   
    #   vehicle.force_idle = false
    #   Vehicle.state_machines['state'].initial_state(vehicle)   # => "parked"
    def initial_state(object)
      @initial_state.is_a?(Proc) ? @initial_state.call(object) : @initial_state
    end
    
    # Defines additional states that are possible in the state machine, but
    # which are derived outside of any events/transitions or possibly
    # dynamically via a lambda block.  This allows the given states to be:
    # * Queried via instance-level predicates
    # * Included in GraphViz visualizations
    # * Used in :except_from and :except_to transition/callback conditionals
    # 
    # == Example
    # 
    #   class Vehicle
    #     state_machine :initial => 'parked' do
    #       event :ignite do
    #         transition :to => 'idling', :from => 'parked'
    #       end
    #        
    #       other_states %w(stalled stopped)
    #     end
    #     
    #     def stop
    #       self.state = 'stopped'
    #     end
    #   end
    # 
    # In the above state machine, the known states would be:
    # * +idling+
    # * +parked+
    # * +stalled+
    # * +stopped+
    # 
    # Since +stalled+ and +stopped+ are not referenced in any transitions or
    # callbacks, they are explicitly defined.
    def other_states(*args)
      add_states(args.flatten)
    end
    
    # Defines an event for the machine.
    # 
    # == Instance methods
    # 
    # The following instance methods are generated when a new event is defined
    # (the "park" event is used as an example):
    # * <tt>can_park?</tt> - Checks whether the "park" event can be fired given the current state of the object.
    # * <tt>next_park_transition</tt> -  Gets the next transition that would be performed if the "park" event were to be fired now on the object or nil if no transitions can be performed.
    # * <tt>park(run_action = true)</tt> - Fires the "park" event, transitioning from the current state to the next valid state.
    # * <tt>park!(run_action = true)</tt> - Fires the "park" event, transitioning from the current state to the next valid state.  If the transition fails, then a StateMachine::InvalidTransition error will be raised.
    # 
    # == Defining transitions
    # 
    # +event+ requires a block which allows you to define the possible
    # transitions that can happen as a result of that event.  For example,
    # 
    #   event :park do
    #     transition :to => 'parked', :from => 'idle'
    #   end
    #   
    #   event :first_gear do
    #     transition :to => 'first_gear', :from => 'parked', :if => :seatbelt_on?
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
    #       %w(parked idling stalled)
    #     end
    #     
    #     state_machine do
    #       event :park do
    #         transition :to => 'parked', :from => Vehicle.safe_states
    #       end
    #     end
    #   end 
    # 
    # == Example
    # 
    #   class Vehicle
    #     state_machine do
    #       event :park do
    #         transition :to => 'parked', :from => %w(first_gear reverse)
    #       end
    #       ...
    #     end
    #   end
    def event(name, &block)
      name = name.to_s
      event = events[name] ||= Event.new(self, name)
      event.instance_eval(&block)
      add_states(event.known_states)
      
      event
    end
    
    # Creates a callback that will be invoked *before* a transition is
    # performed so long as the given configuration options match the transition.
    # Each part of the transition (event, to state, from state) must match in
    # order for the callback to get invoked.
    # 
    # Configuration options:
    # * +to+ - One or more states being transitioned to.  If none are specified, then all states will match.
    # * +from+ - One or more states being transitioned from.  If none are specified, then all states will match.
    # * +on+ - One or more events that fired the transition.  If none are specified, then all events will match.
    # * +except_to+ - One more states *not* being transitioned to
    # * +except_from+ - One or more states *not* being transitioned from
    # * +except_on+ - One or more events that *did not* fire the transition
    # * +do+ - The callback to invoke when a transition matches. This can be a method, proc or string.
    # * +if+ - A method, proc or string to call to determine if the callback should occur (e.g. :if => :allow_callbacks, or :if => lambda {|user| user.signup_step > 2}). The method, proc or string should return or evaluate to a true or false value. 
    # * +unless+ - A method, proc or string to call to determine if the callback should not occur (e.g. :unless => :skip_callbacks, or :unless => lambda {|user| user.signup_step <= 2}). The method, proc or string should return or evaluate to a true or false value. 
    # 
    # The +except+ group of options (+except_to+, +exception_from+, and
    # +except_on+) acts as the +unless+ equivalent of their counterparts (+to+,
    # +from+, and +on+, respectively)
    # 
    # == The callback
    # 
    # When defining additional configuration options, callbacks must be defined
    # in either the :do option or as a block.  For example,
    # 
    #   class Vehicle
    #     state_machine do
    #       before_transition :to => 'parked', :do => :set_alarm
    #       before_transition :to => 'parked' do |vehicle, transition|
    #         vehicle.set_alarm
    #       end
    #       ...
    #     end
    #   end
    # 
    # === Accessing the transition
    # 
    # In addition to passing the object being transitioned, the actual
    # transition describing the context (e.g. event, from state, to state)
    # can be accessed as well.  This additional argument is only passed if the
    # callback allows for it.
    # 
    # For example,
    # 
    #   class Vehicle
    #     # Only specifies one parameter (the object being transitioned)
    #     before_transition :to => 'parked', :do => lambda {|vehicle| vehicle.set_alarm}
    #     
    #     # Specifies 2 parameters (object being transitioned and actual transition)
    #     before_transition :to => 'parked', :do => lambda {|vehicle, transition| vehicle.set_alarm(transition)}
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
    #       before_transition :to => 'parked', :from => %w(first_gear idling), :on => 'park', :do => :take_off_seatbelt
    #       
    #       # With conditional callback:
    #       before_transition :to => 'parked', :do => :take_off_seatbelt, :if => :seatbelt_on?
    #       
    #       # Using :except counterparts:
    #       before_transition :except_to => 'stalled', :except_from => 'stalled', :except_on => 'crash', :do => :update_dashboard
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
    # performed, so long as the given configuration options match the transition.
    # Each part of the transition (event, to state, from state) must match
    # in order for the callback to get invoked.
    # 
    # Configuration options:
    # * +to+ - One or more states being transitioned to.  If none are specified, then all states will match.
    # * +from+ - One or more states being transitioned from.  If none are specified, then all states will match.
    # * +on+ - One or more events that fired the transition.  If none are specified, then all events will match.
    # * +except_to+ - One more states *not* being transitioned to
    # * +except_from+ - One or more states *not* being transitioned from
    # * +except_on+ - One or more events that *did not* fire the transition
    # * +do+ - The callback to invoke when a transition matches. This can be a method, proc or string.
    # * +if+ - A method, proc or string to call to determine if the callback should occur (e.g. :if => :allow_callbacks, or :if => lambda {|user| user.signup_step > 2}). The method, proc or string should return or evaluate to a true or false value. 
    # * +unless+ - A method, proc or string to call to determine if the callback should not occur (e.g. :unless => :skip_callbacks, or :unless => lambda {|user| user.signup_step <= 2}). The method, proc or string should return or evaluate to a true or false value. 
    # 
    # The +except+ group of options (+except_to+, +exception_from+, and
    # +except_on+) acts as the +unless+ equivalent of their counterparts (+to+,
    # +from+, and +on+, respectively)
    # 
    # == The callback
    # 
    # When defining additional configuration options, callbacks must be defined
    # in either the :do option or as a block.  For example,
    # 
    #   class Vehicle
    #     state_machine do
    #       after_transition :to => 'parked', :do => :set_alarm
    #       after_transition :to => 'parked' do |vehicle, transition, result|
    #         vehicle.set_alarm
    #       end
    #       ...
    #     end
    #   end
    # 
    # === Accessing the transition / result
    # 
    # In addition to passing the object being transitioned, the actual
    # transition describing the context (e.g. event, from state, to state) and
    # the result from calling the object's action can be optionally passed as
    # well.  These additional arguments are only passed if the callback allows
    # for it.
    # 
    # For example,
    # 
    #   class Vehicle
    #     # Only specifies one parameter (the object being transitioned)
    #     after_transition :to => 'parked', :do => lambda {|vehicle| vehicle.set_alarm}
    #     
    #     # Specifies 3 parameters (object being transitioned, transition, and action result)
    #     after_transition :to => 'parked', :do => lambda {|vehicle, transition, result| vehicle.set_alarm(transition) if result}
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
    # Below is an example of a model with one state machine and various types
    # of +after+ transitions defined for it:
    # 
    #   class Vehicle
    #     state_machine do
    #       # After all transitions
    #       after_transition :update_dashboard
    #       
    #       # After specific transition:
    #       after_transition :to => 'parked', :from => %w(first_gear idling), :on => 'park', :do => :take_off_seatbelt
    #       
    #       # With conditional callback:
    #       after_transition :to => 'parked', :do => :take_off_seatbelt, :if => :seatbelt_on?
    #       
    #       # Using :except counterparts:
    #       after_transition :except_to => 'stalled', :except_from => 'stalled', :except_on => 'crash', :do => :update_dashboard
    #       ...
    #     end
    #   end
    # 
    # As can be seen, any number of transitions can be created using various
    # combinations of configuration options.
    def after_transition(options = {}, &block)
      add_callback(:after, options.is_a?(Hash) ? options : {:do => options}, &block)
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
    # * +name+ - The name of the file to write to (without the file extension).  Default is "#{owner_class.name}_#{attribute}"
    # * +path+ - The path to write the graph file to.  Default is the current directory (".").
    # * +format+ - The image format to generate the graph in.  Default is "png'.
    # * +font+ - The name of the font to draw state names in.  Default is "Arial'.
    def draw(options = {})
      options = {
        :name => "#{owner_class.name}_#{attribute}",
        :path => '.',
        :format => 'png',
        :font => 'Arial'
      }.merge(options)
      assert_valid_keys(options, :name, :font, :path, :format)
      
      begin
        # Load the graphviz library
        require 'rubygems'
        require 'graphviz'
        
        graph = GraphViz.new('G', :output => options[:format], :file => File.join(options[:path], "#{options[:name]}.#{options[:format]}"))
        
        # Tracks unique identifiers for dynamic states (via lambda blocks)
        dynamic_states = {}
        dynamic_id = 0
        
        # Add nodes
        states.each do |state|
          shape = state == @initial_state ? 'doublecircle' : 'circle'
          
          # Use GraphViz-friendly name/label for dynamic/nil states
          if state.is_a?(Proc)
            name = "lambda#{dynamic_id += 1}"
            label = '*'
            dynamic_states[state] = name
          else
            name = label = state.nil? ? 'nil' : state.to_s
          end
          
          graph.add_node(name, :label => label, :width => '1', :height => '1', :fixedsize => 'true', :shape => shape, :fontname => options[:font])
        end
        
        # Add edges
        events.values.each do |event|
          event.guards.each do |guard|
            # From states: :from, everything but :except states, or all states
            from_states = guard.requirements[:from] || guard.requirements[:except_from] && (states - guard.requirements[:except_from]) || states
            if to_state = guard.requirements[:to]
              to_state = to_state.first
              
              # Convert to GraphViz-friendly name
              to_state = case to_state
                when Proc; dynamic_states[to_state]
                when nil; 'nil'
                else; to_state.to_s; end
            end
            
            from_states.each do |from_state|
              # Convert to GraphViz-friendly name
              from_state = case from_state
                when Proc; dynamic_states[from_state]
                when nil; 'nil'
                else; from_state.to_s; end
              
              graph.add_edge(from_state, to_state || from_state, :label => event.name, :fontname => options[:font])
            end
          end
        end
        
        # Generate the graph
        graph.output
        
        true
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
      
      # Adds reader/writer/prediate methods for accessing the attribute that
      # this state machine is defined for.
      def define_attribute_accessor
        attribute = self.attribute
        
        owner_class.class_eval do
          attr_reader attribute unless method_defined?(attribute) || private_method_defined?(attribute)
          attr_writer attribute unless method_defined?("#{attribute}=") || private_method_defined?("#{attribute}=")
          
          # Checks whether the current state is a given value.  If the value
          # is not a known state, then an ArgumentError is raised.
          define_method("#{attribute}?") do |state|
            raise ArgumentError, "#{state.inspect} is not a known #{attribute} value" unless self.class.state_machines[attribute].states.include?(state)
            send(attribute) == state
          end unless method_defined?("#{attribute}?") || private_method_defined?("#{attribute}?")
        end
      end
      
      # Defines the with/without scope helpers for this attribute.  Both the
      # singular and plural versions of the attribute are defined for each
      # scope helper.  A custom plural can be specified if it cannot be
      # automatically determined by either calling +pluralize+ on the attribute
      # name or adding an "s" to the end of the name.
      def define_scopes(custom_plural = nil)
        plural = custom_plural || (attribute.respond_to?(:pluralize) ? attribute.pluralize : "#{attribute}s")
        
        [attribute, plural].uniq.each do |name|
          define_with_scope("with_#{name}") unless owner_class.respond_to?("with_#{name}")
          define_without_scope("without_#{name}") unless owner_class.respond_to?("without_#{name}")
        end
      end
      
      # Defines a scope for finding objects *with* a particular value or
      # values for the attribute.
      # 
      # This is only applicable to specific integrations.
      def define_with_scope(name)
      end
      
      # Defines a scope for finding objects *without* a particular value or
      # values for the attribute.
      # 
      # This is only applicable to specific integrations.
      def define_without_scope(name)
      end
      
      # Adds a new transition callback of the given type.
      def add_callback(type, options, &block)
        @callbacks[type] << callback = Callback.new(options, &block)
        add_states(callback.known_states)
        callback
      end
      
      # Tracks the given set of states in the list of all known states for
      # this machine
      def add_states(states)
        new_states = states - @states
        @states += new_states
        
        # Add state predicates
        attribute = self.attribute
        new_states.each do |state|
          if state && (state.is_a?(String) || state.is_a?(Symbol))
            name = "#{state}?"
            
            owner_class.class_eval do
              # Checks whether the current state is equal to the given value
              define_method(name) do
                self.send(attribute) == state
              end unless method_defined?(name) || private_method_defined?(name)
            end
          end
        end
      end
  end
end
