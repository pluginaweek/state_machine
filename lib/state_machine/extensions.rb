module PluginAWeek #:nodoc:
  module StateMachine
    module ClassMethods
      def self.extended(base) #:nodoc:
        base.class_eval do
          @state_machines = {}
        end
      end
      
      # Ensures that the +initialize+ hook defined in PluginAWeek::StateMachine::InstanceMethods
      # remains there even if the class defines its own +initialize+ method
      # *after* the state machine has been defined.  For example,
      # 
      #   class Switch
      #     state_machine do
      #       ...
      #     end
      #     
      #     def initialize(attributes = {})
      #       ...
      #     end
      #   end
      def method_added(method) #:nodoc:
        super
        
        # Aliasing the +initialize+ method also invokes +method_added+, so
        # alias processing is tracked to prevent an infinite loop
        if !@skip_initialize_hook && [:initialize, :initialize_with_state_machine].include?(method)
          @skip_initialize_hook = true
          alias_method :initialize_without_state_machine, :initialize
          alias_method :initialize, :initialize_with_state_machine
          @skip_initialize_hook = false
        end
      end
      
      # Gets the current list of state machines defined for this class.  This
      # class-level attribute acts like an inheritable attribute.  The attribute
      # is available to each subclass, each subclass having a copy of it's
      # superclass's attribute.
      # 
      # The hash of state machines maps +name+ => +machine+, e.g.
      # 
      #   Vehicle.state_machines # => {:state => #<PluginAWeek::StateMachine::Machine:0xb6f6e4a4 ...>
      def state_machines
        @state_machines ||= superclass.state_machines.dup
      end
    end
    
    module InstanceMethods
      def self.included(base) #:nodoc:
        # Methods added from an included module don't invoke +method_added+,
        # triggering the initialize alias, so it's done explicitly
        base.method_added(:initialize_with_state_machine)
      end
      
      # Defines the initial values for state machine attributes.  The values
      # will be set *after* the original initialize method is invoked.  This is
      # necessary in order to ensure that the object is initialized before
      # dynamic initial attributes are evaluated.
      def initialize_with_state_machine(*args, &block)
        initialize_without_state_machine(*args, &block)
        
        self.class.state_machines.each do |attribute, machine|
          # Set the initial value of the machine's attribute unless it already
          # exists (which must mean the defaults are being skipped)
          send("#{attribute}=", machine.initial_state(self)) unless send(attribute)
        end
      end
    end
  end
end
