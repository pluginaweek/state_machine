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
        
        add_transition_actions
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
        
        # Get the states involved in the transition
        to_state = options.delete(:to)
        from_states = Array(options.delete(:from))
        
        from_states.collect do |from_state|
          # Create the actual transition that will update records when performed
          transition = Transition.new(self, from_state, to_state)
          
          # Add the callback to the model. If the callback fails, then the next
          # available callback for the event will run until one is successful.
          callback = Proc.new {|record, *args| try_transition(transition, false, record, *args)}
          owner_class.send("transition_on_#{name}", callback, options)
          
          # Add the callback! to the model similar to above
          callback = Proc.new {|record, *args| try_transition(transition, true, record, *args)}
          owner_class.send("transition_bang_on_#{name}", callback, options)
          
          transition
        end
      end
      
      # Attempts to perform one of the event's transitions for the given record
      def fire(record, *args)
        record.class.transaction {invoke_transition_callbacks(record, false, *args) || raise(ActiveRecord::Rollback)} || false
      end
      
      # Attempts to perform one of the event's transitions for the given record.
      # If the transition cannot be made, then a PluginAWeek::StateMachine::InvalidTransition
      # error will be raised.
      def fire!(record, *args)
        record.class.transaction {invoke_transition_callbacks(record, true, *args) || raise(ActiveRecord::Rollback)} || raise(PluginAWeek::StateMachine::InvalidTransition)
      end
      
      private
        # Add the various instance methods that can transition the record using
        # the current event
        def add_transition_actions
          name = self.name
          owner_class = self.owner_class
          machine = self.machine
          
          owner_class.class_eval do
            # Fires the event, returning true/false
            define_method(name) do |*args|
              owner_class.state_machines[machine.attribute].events[name].fire(self, *args)
            end
            
            # Fires the event, raising an exception if it fails
            define_method("#{name}!") do |*args|
              owner_class.state_machines[machine.attribute].events[name].fire!(self, *args)
            end
          end
        end
        
        # Defines callbacks for invoking transitions when this event is performed
        def add_transition_callbacks
          %W(transition transition_bang).each do |callback_name|
            callback_name = "#{callback_name}_on_#{name}"
            owner_class.define_callbacks(callback_name)
          end
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
        
        # Attempts to perform the given transition. If it can't be performed based
        # on the state of the given record, then the transition will be skipped
        # and the next available one will be tried.
        # 
        # If +bang+ is specified, then perform! will be called on the transition.
        # Otherwise, the default +perform+ will be invoked.
        def try_transition(transition, bang, record, *args)
          if transition.can_perform_on?(record)
            return false if invoke_event_callbacks(:before, record, *args) == false
            result = bang ? transition.perform!(record, *args) : transition.perform(record, *args)
            invoke_event_callbacks(:after, record, *args)
            result
          else
            # Indicate that the transition cannot be performed
            :skip
          end
        end
        
        # Invokes a particulary type of callback for the event
        def invoke_event_callbacks(type, record, *args)
          args = [record] + args
          
          record.class.send("#{type}_#{name}_callback_chain").each do |callback|
            result = callback.call(*args)
            break result if result == false
          end
        end
        
        # Invokes the callbacks for each transition in order to find one that
        # completes successfully.
        # 
        # +bang+ indicates whether perform or perform! will be invoked on the
        # transitions in the callback chain
        def invoke_transition_callbacks(record, bang, *args)
          args = [record] + args
          callback_chain = "transition#{'_bang' if bang}_on_#{name}_callback_chain"
          
          result = record.class.send(callback_chain).each do |callback|
            result = callback.call(*args)
            break result if [true, false].include?(result)
          end
          result == true
        end
    end
  end
end
