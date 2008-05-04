require 'state_machine/transition'

module PluginAWeek #:nodoc:
  module StateMachine
    # An event defines an action that transitions an attribute from one state to
    # another
    class Event
      # The state machine for which this event is defined
      attr_reader :machine
      
      # The name of the action that fires the event
      attr_reader :name
      
      delegate  :owner_class,
                  :to => :machine
      
      # Creates a new event with the given name
      def initialize(machine, name, options = {})
        options.assert_valid_keys(:before, :after)
        
        @machine = machine
        @name = name
        @options = options.stringify_keys
        
        add_transition_action
        add_transition_callbacks
        add_event_callbacks
      end
      
      # Creates a new transition to the specified state.
      # 
      # Configuration options:
      # * +to+ - The state that being transitioned to
      # * +from+ - A state or array of states that can be transitioned from
      # * +if+ - Specifies a method, proc or string to call to determine if the validation should occur (e.g. :if => :moving?, or :if => Proc.new {|car| car.speed > 60}). The method, proc or string should return or evaluate to a true or false value.
      # * +unless+ - Specifies a method, proc or string to call to determine if the transition should not occur (e.g. :unless => :stopped?, or :unless => Proc.new {|car| car.speed <= 60}). The method, proc or string should return or evaluate to a true or false value.
      # 
      # == Examples
      # 
      #   transition :to => 'parked', :from => 'first_gear'
      #   transition :to => 'parked', :from => %w(first_gear reverse)
      #   transition :to => 'parked', :from => 'first_gear', :if => :moving?
      #   transition :to => 'parked', :from => 'first_gear', :unless => :stopped?
      def transition(options = {})
        options.symbolize_keys!
        options.assert_valid_keys(:to, :from, :if, :unless)
        raise ArgumentError, ':to state must be specified' unless options.include?(:to)
        
        to_state = options.delete(:to)
        from_states = Array(options.delete(:from))
        from_states.collect do |from_state|
          # Create the actual transition that will update records when run
          transition = Transition.new(self, from_state, to_state)
          
          # The callback that will be invoked when the event is run. If the callback
          # fails, then the next available callback for the event will run until
          # one is successful.
          callback = Proc.new do |record, *args|
            transition.can_perform_on?(record) &&
            invoke_event_callbacks(:before, record, *args) != false &&
            transition.perform(record, *args) &&
            invoke_event_callbacks(:after, record, *args) != false
          end
          
          # Add the callback to the model
          owner_class.send("transition_on_#{name}", callback, options)
          
          transition
        end
      end
      
      # Attempts to transition to one of the next possible states for the given record
      def fire!(record, *args)
        success = false
        record.class.transaction {success = invoke_transition_callbacks(record, *args) == true || raise(ActiveRecord::Rollback)}
        success
      end
      
      private
        # Add action for transitioning the record
        def add_transition_action
          owner_class.class_eval <<-end_eval
            def #{name}!(*args)
              #{owner_class}.state_machines['#{machine.attribute}'].events['#{name}'].fire!(self, *args)
            end
          end_eval
        end
        
        # Defines callbacks for invoking transitions when this event is performed
        def add_transition_callbacks
          owner_class.define_callbacks("transition_on_#{name}")
        end
        
        # Adds the before/after callbacks for when the event is performed
        def add_event_callbacks
          %w(before after).each do |type|
            callback_name = "#{type}_#{name}"
            owner_class.define_callbacks(callback_name)
            
            # Add each defined callback
            Array(@options[type]).each {|callback| owner_class.send(callback_name, callback)}
          end
        end
        
        # Invokes a particulary type of callbacks for the event
        def invoke_event_callbacks(type, record, *args)
          args = [record] + args
          
          record.class.send("#{type}_#{name}_callback_chain").each do |callback|
            result = callback.call(*args)
            break result if result == false
          end
        end
        
        # Invokes the callbacks for each transition in order to find one that
        # completes successfully
        def invoke_transition_callbacks(record, *args)
          args = [record] + args
          
          record.class.send("transition_on_#{name}_callback_chain").each do |callback|
            result = callback.call(*args)
            break result if result == true
          end
        end
    end
  end
end
