module StateMachine
  module ClassMethods
    def self.extended(base) #:nodoc:
      base.class_eval do
        @state_machines = {}
      end
    end
    
    # Gets the current list of state machines defined for this class.  This
    # class-level attribute acts like an inheritable attribute.  The attribute
    # is available to each subclass, each subclass having a copy of its
    # superclass's attribute.
    # 
    # The hash of state machines maps +attribute+ => +machine+, e.g.
    # 
    #   Vehicle.state_machines # => {:state => #<StateMachine::Machine:0xb6f6e4a4 ...>
    def state_machines
      @state_machines ||= superclass.state_machines.dup
    end
  end
  
  module InstanceMethods
    # Defines the initial values for state machine attributes.  The values
    # will be set *after* the original initialize method is invoked.  This is
    # necessary in order to ensure that the object is initialized before
    # dynamic initial attributes are evaluated.
    def initialize(*args, &block)
      super
      initialize_state_machines
    end
    
    protected
      def initialize_state_machines #:nodoc:
        self.class.state_machines.each do |attribute, machine|
          # Set the initial value of the machine's attribute unless it already
          # exists (which must mean the defaults are being skipped)
          value = send(attribute)
          send("#{attribute}=", machine.initial_state(self).value) if value.nil? || value.respond_to?(:empty?) && value.empty?
        end
      end
  end
end
