require 'state_machine/machine'

module PluginAWeek #:nodoc:
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
      # transitions, a reader/writer must be available.  If these methods are
      # not already defined, then they will be automatically generated.
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
      # == Events and Transitions
      # 
      # For more information about how to configure an event and its associated
      # transitions, see PluginAWeek::StateMachine::Machine#event.
      # 
      # == Defining callbacks
      # 
      # Within the +state_machine+ block, you can also define callbacks for
      # particular states.  For more information about defining these callbacks,
      # see PluginAWeek::StateMachine::Machine#before_transition and
      # PluginAWeek::StateMachine::Machine#after_transition.
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
      # See PluginAWeek::StateMachine::Machine for more information about using
      # integrations and the individual integration docs for information about
      # the actual scopes that are generated.
      def state_machine(*args, &block)
        machine = PluginAWeek::StateMachine::Machine.find_or_create(self, *args)
        machine.instance_eval(&block) if block
        machine
      end
    end
  end
end

Class.class_eval do
  include PluginAWeek::StateMachine::MacroMethods
end
