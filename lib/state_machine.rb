require 'state_machine/machine'

# A state machine is a model of behavior composed of states, events, and
# transitions.  This helper adds support for defining this type of
# functionality on any Ruby class.
module StateMachine
  module MacroMethods
    # Creates a new state machine for the given attribute.  The default
    # attribute, if not specified, is "state".
    # 
    # Configuration options:
    # * +initial+ - The initial value to set the attribute to. This can be a static value or a dynamic proc which will be evaluated at runtime.  Default is nil.
    # * +action+ - The action to invoke when an object transitions.  Default is nil unless otherwise specified by the configured integration.
    # * +plural+ - The pluralized name of the attribute.  By default, this will attempt to call +pluralize+ on the attribute, otherwise an "s" is appended.
    # * +integration+ - The name of the integration to use for adding library-specific behavior to the machine.  Built-in integrations include :data_mapper and :active_record.  By default, this is determined automatically.
    # 
    # This also requires a block which will be used to actually configure the
    # events and transitions for the state machine.  *Note* that this block
    # will be executed within the context of the state machine.  As a result,
    # you will not be able to access any class methods unless you refer to
    # them directly (i.e. specifying the class name).
    # 
    # For examples on the types of configured state machines and blocks, see
    # the section below.
    # 
    # == Examples
    # 
    # With the default attribute and no configuration:
    # 
    #   class Vehicle
    #     state_machine do
    #       event :park do
    #         ...
    #       end
    #     end
    #   end
    # 
    # The above example will define a state machine for the attribute "state"
    # on the class.  Every vehicle will start without an initial state.
    # 
    # With a custom attribute:
    # 
    #   class Vehicle
    #     state_machine :status do
    #       ...
    #     end
    #   end
    # 
    # With a static initial state:
    # 
    #   class Vehicle
    #     state_machine :status, :initial => 'Vehicle' do
    #       ...
    #     end
    #   end
    # 
    # With a dynamic initial state:
    # 
    #   class Switch
    #     state_machine :status, :initial => lambda {|switch| (8..22).include?(Time.now.hour) ? 'on' : 'off'} do
    #       ...
    #     end
    #   end
    # 
    # == Attribute accessor
    # 
    # The attribute for each machine stores the value for the current state
    # of the machine.  In order to access this value and modify it during
    # transitions, a reader/writer must be available.  The following methods
    # will be automatically generated if they are not already defined
    # (assuming the attribute is called "state"):
    # * <tt>state</tt> - Gets the current value for the attribute
    # * <tt>state=(value)</tt> - Sets the current value for the attribute
    # * <tt>state?(value)</tt> - Checks the given value against the current value.  If the value is not a known state, then an ArgumentError is raised.
    # 
    # For example, the following machine definition will not generate any
    # accessor methods since the class has already defined an attribute
    # accessor:
    # 
    #   class Vehicle
    #     attr_accessor :state
    #     
    #     state_machine do
    #       ...
    #     end
    #   end
    # 
    # On the other hand, the following state machine will define both a
    # reader and writer method, which is functionally equivalent to the
    # example above:
    # 
    #   class Vehicle
    #     state_machine do
    #       ...
    #     end
    #   end
    # 
    # == States
    # 
    # All of the valid states for the machine are automatically tracked based
    # on the events, transitions, and callbacks defined for the machine.  If
    # there are additional states that are never referenced, these should be
    # explicitly added using the StateMachine::Machine#other_states
    # helper.
    # 
    # For each state tracked, a predicate method for that state is generated
    # on the class.  For example,
    # 
    #   class Vehicle
    #     state_machine :initial => 'parked' do
    #       event :ignite do
    #         transition :to => 'idling'
    #       end
    #     end
    #   end
    # 
    # ...will generate the following instance methods (assuming they're not
    # already defined in the class):
    # * <tt>parked?</tt>
    # * <tt>idling?</tt>
    # 
    # Each predicate method will return true if it matches the object's
    # current state.  Otherwise, it will return false.
    # 
    # == Events and Transitions
    # 
    # For more information about how to configure an event and its associated
    # transitions, see StateMachine::Machine#event.
    # 
    # == Defining callbacks
    # 
    # Within the +state_machine+ block, you can also define callbacks for
    # particular states.  For more information about defining these callbacks,
    # see StateMachine::Machine#before_transition and
    # StateMachine::Machine#after_transition.
    # 
    # == Scopes
    # 
    # For integrations that support it, a group of default scope filters will
    # be automatically created for assisting in finding objects that have the
    # attribute set to a given value.
    # 
    # For example,
    # 
    #   Vehicle.with_state('parked') # => Finds all vehicles where the state is parked
    #   Vehicle.with_states('parked', 'idling') # => Finds all vehicles where the state is either parked or idling
    #   
    #   Vehicle.without_state('parked') # => Finds all vehicles where the state is *not* parked
    #   Vehicle.without_states('parked', 'idling') # => Finds all vehicles where the state is *not* parked or idling
    # 
    # *Note* that if class methods already exist with those names (i.e.
    # "with_state", "with_states", "without_state", or "without_states"), then
    # a scope will not be defined for that name.
    # 
    # See StateMachine::Machine for more information about using
    # integrations and the individual integration docs for information about
    # the actual scopes that are generated.
    def state_machine(*args, &block)
      StateMachine::Machine.find_or_create(self, *args, &block)
    end
  end
end

Class.class_eval do
  include StateMachine::MacroMethods
end
