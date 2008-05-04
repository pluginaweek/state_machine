require 'state_machine/event'

module PluginAWeek #:nodoc:
  module StateMachine
    # Represents a state machine for a particular attribute
    # 
    # == State callbacks
    # 
    # These callbacks are invoked in the following order:
    # 1. before_exit (old state)
    # 2. before_enter (new state)
    # 3. after_exit (old state)
    # 4. after_enter (new state)
    class Machine
      # The events that trigger transitions
      attr_reader :events
      
      # The attribute for which the state machine is being defined
      attr_accessor :attribute
      
      # The initial state that the machine will be in
      attr_reader :initial_state
      
      # The class that the attribute belongs to
      attr_reader :owner_class
      
      # Creates a new state machine for the given attribute
      # 
      # Configuration options:
      # * +initial+ - The initial value to set the attribute to
      # 
      # == Scopes
      # 
      # This will automatically created a named scope called with_#{attribute}
      # that will find all records that have the attribute set to a given value.
      # For example,
      # 
      #   Switch.with_state('on') # => Finds all switches where the state is on
      #   Switch.with_states('on', 'off') # => Finds all switches where the state is either on or off
      def initialize(owner_class, attribute, options = {})
        options.assert_valid_keys(:initial)
        
        @owner_class = owner_class
        @attribute = attribute.to_s
        @initial_state = options[:initial]
        @events = {}
        
        add_named_scopes
      end
      
      # Gets the initial state of the machine for the given record. The record
      # is only used if a dynamic initial state is being used
      def initial_state(record)
        @initial_state.is_a?(Proc) ? @initial_state.call(record) : @initial_state
      end
      
      # Gets the initial state without processing it against a particular record
      def initial_state_without_processing
        @initial_state
      end
      
      # Defines an event of the system.  This can take an optional hash that
      # defines callbacks which will be invoked when the object enters/exits
      # the event.
      # 
      # Configuration options:
      # * +before+ - Invoked before the event has been executed
      # * +after+ - Invoked after the event has been executed
      # 
      # == Callback order
      # 
      # These callbacks are invoked in the following order:
      # 1. before
      # 2. after
      # 
      # == Instance methods
      # 
      # The following instance methods are generated when a new event is defined
      # (the "park" event is used as an example):
      # * <tt>park!(*args)</tt> - Fires the "park" event, transitioning from the current state to the next valid state.  This takes an optional +args+ list which is passed to the event callbacks.
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
      # See PluginAWeek::StateMachine::Event#transition for more information on
      # the possible options that can be passed in.
      # 
      # == Example
      # 
      #   class Car < ActiveRecord::Base
      #     state_machine(:state, :initial => 'parked') do
      #       event :park, :after => :release_seatbelt do
      #         transition :to => 'parked', :from => %w(first_gear reverse)
      #       end
      #       ...
      #     end
      #   end
      def event(name, options = {}, &block)
        name = name.to_s
        event = events[name] = Event.new(self, name, options)
        event.instance_eval(&block)
        event
      end
      
      # Define state callbacks
      %w(before_exit before_enter after_exit after_enter).each do |callback|
        module_eval <<-end_eval
          def #{callback}(state, callback)
            callback_name = "#{callback}_\#{attribute}_\#{state}"
            owner_class.define_callbacks(callback_name)
            owner_class.send(callback_name, callback)
          end
        end_eval
      end
      
      private
        def add_named_scopes
          unless owner_class.respond_to?("with_#{attribute}")
            # How do you alias named scopes? (doesn't work completely with a simple alias/alias_method)
            %W(with_#{attribute} with_#{attribute.pluralize}).each do |scope_name|
              owner_class.class_eval <<-end_eos
                named_scope :#{scope_name}, Proc.new {|*values| {
                  :conditions => {:#{attribute} => values.flatten}
                }}
              end_eos
            end
          end
        end
    end
  end
end
