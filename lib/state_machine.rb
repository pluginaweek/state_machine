require 'state_machine/machine'

module PluginAWeek #:nodoc:
  # A state machine is a model of behavior composed of states, transitions,
  # and events.  This helper adds support for defining this type of
  # functionality within your ActiveRecord models.
  module StateMachine
    def self.included(base) #:nodoc:
      base.class_eval do
        extend PluginAWeek::StateMachine::MacroMethods
      end
    end
    
    module MacroMethods
      # Creates a state machine for the given attribute.
      # 
      # Configuration options:
      # * +initial+ - The initial value of the attribute.  This can either be the actual value or a Proc for dynamic initial states.
      # 
      # == Example
      # 
      # With a static state:
      # 
      #   class Switch < ActiveRecord::Base
      #     state_machine :state, :initial => 'off' do
      #       ...
      #     end
      #   end
      # 
      # With a dynamic state:
      # 
      #   class Switch < ActiveRecord::Base
      #     state_machine :state, :initial => Proc.new {|switch| (8..22).include?(Time.now.hour) ? 'on' : 'off'} do
      #       ...
      #     end
      #   end
      def state_machine(attribute, options = {}, &block)
        unless included_modules.include?(PluginAWeek::StateMachine::InstanceMethods)
          write_inheritable_attribute :state_machines, {}
          class_inheritable_reader :state_machines
          
          after_create :run_initial_state_machine_actions
          
          include PluginAWeek::StateMachine::InstanceMethods
        end
        
        # This will create a new machine for subclasses as well so that the owner_class and
        # initial state can be overridden
        attribute = attribute.to_s
        options[:initial] = state_machines[attribute].initial_state_without_processing if !options.include?(:initial) && state_machines[attribute]
        machine = state_machines[attribute] = PluginAWeek::StateMachine::Machine.new(self, attribute, options)
        machine.instance_eval(&block) if block
        machine
      end
    end
    
    module InstanceMethods
      def self.included(base) #:nodoc:
        base.class_eval do
          alias_method_chain :initialize, :state_machine
        end
      end
      
      # Defines the initial values for state machine attributes
      def initialize_with_state_machine(attributes = nil)
        initialize_without_state_machine(attributes)
        
        attribute_keys = (attributes || {}).keys.map!(&:to_s)
        
        self.class.state_machines.each do |attribute, machine|
          unless attribute_keys.include?(attribute)
            send("#{attribute}=", machine.initial_state(self))
          end
        end
        
        yield self if block_given?
      end
      
      # Records the transition for the record going into its initial state
      def run_initial_state_machine_actions
        self.class.state_machines.each do |attribute, machine|
          callback = "after_enter_#{attribute}_#{self[attribute]}"
          run_callbacks(callback) if self.class.respond_to?(callback)
        end
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include PluginAWeek::StateMachine
end
