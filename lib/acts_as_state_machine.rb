require 'dry_transaction_rollbacks'

module PluginAWeek #:nodoc:
  module Acts #:nodoc:
    module StateMachine
      
      # An unknown state was specified
      #
      class InvalidState < Exception #:nodoc:
      end
      
      # An unknown event was specified
      #
      class InvalidEvent < Exception #:nodoc:
      end
      
      # No initial state was specified for the machine
      #
      class NoInitialState < Exception #:nodoc:
      end
      
      def self.included(base) #:nodoc:
        base.extend(MacroMethods)
      end
      
      module SupportingClasses #:nodoc:
        # Represents a state in the machine
        #
        class State
          attr_reader :model
          delegate    :name, :id, :to => :model
          
          def initialize(model, options)
            options.symbolize_keys!.assert_valid_keys(
              :enter,
              :after,
              :exit,
              :deadline_passed_event
            )
            options.reverse_merge!(
              :deadline_passed_event => "#{model.name}_deadline_passed"
            )
            
            @model, @options = model, options
          end
          
          #
          #
          def deadline_passed_event
            "#{@options[:deadline_passed_event]}!"
          end
          
          # Indicates that the state is being entered
          #
          def entering(record)
            # If the class supports deadlines, then see if we can set it now
            if record.class.use_state_deadlines && record.respond_to?("set_#{name}_deadline")
              record.send("set_#{name}_deadline")
            end
            
            # Execute the actions for entering
            if enter_actions = @options[:enter]
              Array(enter_actions).each do |action|
                record.send(:run_transition_action, action)
              end
            end
          end
          
          # Indicates that the state has been entered
          #
          def entered(record)
            # Execute the actions after entering the state
            if after_actions = @options[:after]
              Array(after_actions).each do |action|
                record.send(:run_transition_action, action)
              end
            end
          end
          
          # Indicates the the state has been exited
          #
          def exited(record)
            # Execute the actions for exiting
            if exit_actions = @options[:exit]
              Array(exit_actions).each do |action|
                record.send(:run_transition_action, action)
              end
            end
          end
        end
        
        # Represents a transition in the machine.  A transition consists of:
        #   -The starting state
        #   -The ending state
        #   -A guard to check if the transition is allowed
        #
        class StateTransition
          attr_reader :from_name, :to_name, :options
          
          def initialize(from_name, to_name, options) #:nodoc:
            options.symbolize_keys!.assert_valid_keys(:guard)
            
            @from_name, @to_name, @guard = from_name.to_s, to_name.to_s, options[:guard]
          end
          
          # Ensures that the transition can occur by checking the guard associated
          # with it
          #
          def guard(record)
            @guard ? record.send(:run_transition_action, @guard) : true
          end
          
          # Runs the actual transition and any actions associated with entering
          # and exiting the states
          #
          def perform(record)
            return false unless guard(record)
            
            loopback = record.state_name == to_name
            
            next_state = record.class.states[to_name]
            old_state = record.class.states[record.state_name]
            
            # Start entering the next state
            next_state.entering(record) unless loopback
            
            # Update that we've entered the state
            record.state = next_state.model
            
            # Enter the next state
            next_state.entered(record) unless loopback
            
            # Leave the last state
            old_state.exited(record) unless loopback
            
            true
          end
          
          def ==(obj) #:nodoc:
            @from_name == obj.from_name && @to_name == obj.to_name
          end
        end
        
        #
        #
        class Event
          attr_reader :model,
                      :transitions,
                      :options
          
          delegate    :name, :id, :to => :model
          
          #
          #
          def initialize(model, options, transitions, valid_state_names, &block)
            @model = model
            @options = options.symbolize_keys!
            @transitions = transitions[name] = []
            @valid_state_names = valid_state_names
            
            instance_eval(&block) if block
          end
          
          #
          #
          def next_states(record)
            @transitions.select {|transition| transition.from_name == record.state_name}
          end
          
          #
          #
          def fire(record, options)
            options = options.merge(:use_transaction => false)
            success = false
            
            original_state_name = record.state_name
            next_states(record).each do |transition|
              if success = transition.perform(record)
                record.record_transition(name, original_state_name, record.state_name)
                break
              end
            end
            
            # Execute the event on all other state machines running in parallel
            if parallel_state_machines = options[:parallel]
              parallel_state_machines = [parallel_state_machines].flatten.inject({}) do |machine_events, machine|
                if machine.is_a?(Hash)
                  machine_events.merge(machine)
                else
                  machine_events[machine] = name
                end
                machine_events
              end
              
              parallel_state_machines.each do |machine, event|
                machine = Symbol === machine ? record.send(machine) : machine.call(self)
                success = machine.send("#{event}!", options)
                
                break if !success
              end
            end
            
            success
          end
          
          #
          # 
          def transition_to(to_name, options = {})
            raise InvalidState, "#{to_name} is not a valid state for #{self.name}" unless @valid_state_names.include?(to_name.to_s)
            
            options.symbolize_keys!
            
            Array(options.delete(:from)).each do |from_name|
              raise InvalidState, "#{from_name} is not a valid state for #{self.name}" unless @valid_state_names.include?(from_name.to_s)
              
              @transitions << SupportingClasses::StateTransition.new(from_name, to_name, options)
            end
          end
        end
      end
      
      module MacroMethods
        # Configuration options:
        # * <tt>initial</tt> - Specifies an initial state for newly created objects (required)
        # * <tt>use_deadlines</tt> - 
        # 
        def acts_as_state_machine(options)
          options.assert_valid_keys(
            :initial,
            :use_deadlines
          )
          raise NoInitialState unless options[:initial]
          
          options.reverse_merge!(:use_deadlines => false)
          
          model_name = "::#{self.name}"
          model_assoc_name = model_name.demodulize.underscore
          
          # Create the State model
          const_set('State', Class.new(::State)).class_eval do
            def self.reloadable?
              false
            end
          end
          
          # Create a model for recording each change in state
          const_set('Event', Class.new(::Event)).class_eval do
            def self.reloadable?
              false
            end
          end
          
          # Create a model for recording each change in state
          const_set('StateChange', Class.new(::StateChange)).class_eval do
            belongs_to  :stateful,
                          :class_name => model_name,
                          :foreign_key => 'stateful_id',
                          :dependent => :destroy
            
            alias_method    model_assoc_name, :stateful
            alias_attribute "#{model_assoc_name}_id", :stateful_id
            
            def self.reloadable?
              false
            end
          end
          
          # Create a model for tracking a deadline for each state
          use_deadlines = options[:use_deadlines]
          if use_deadlines
            const_set('StateDeadline', Class.new(::StateDeadline)).class_eval do
              belongs_to  :stateful,
                            :class_name => model_name,
                            :foreign_key => 'stateful_id',
                            :dependent => :destroy
              
              alias_method    model_assoc_name, :stateful
              alias_attribute "#{model_assoc_name}_id", :stateful_id
              
              def self.reloadable?
                false
              end
            end
          end
          
          write_inheritable_attribute :states, {}
          write_inheritable_attribute :initial_state_name, options[:initial]
          write_inheritable_attribute :transitions, {}
          write_inheritable_attribute :events, {}
          write_inheritable_attribute :use_state_deadlines, use_deadlines
          
          class_inheritable_reader    :states
          class_inheritable_reader    :transitions
          class_inheritable_reader    :events
          class_inheritable_reader    :use_state_deadlines
          
          before_create               :set_initial_state_id
          after_create                :run_initial_state_actions
          
          module_eval <<-end_eval
            module StateExtension
              def find_in_states(number, state_names, *args)
                @reflection.klass.with_state_scope(state_names) do
                  find(number, *args)
                end
              end
            end
          end_eval
          
          belongs_to  :state,
                        :class_name => "#{model_name}::State",
                        :foreign_key => 'state_id'
          has_many    :state_changes,
                        :class_name => "#{model_name}::StateChange",
                        :foreign_key => 'stateful_id',
                        :dependent => :destroy
          has_many    :state_deadlines,
                        :class_name => "#{model_name}::StateDeadline",
                        :foreign_key => 'stateful_id',
                        :dependent => :destroy if use_deadlines
          
          extend PluginAWeek::Acts::StateMachine::ClassMethods
          include PluginAWeek::Acts::StateMachine::InstanceMethods
        end
      end
      
      module InstanceMethods
        def self.included(base)
          base.class_eval do
            alias_method_chain :state, :initial_check
          end
        end
        
        #
        #
        def initial_state_name
          name = self.class.read_inheritable_attribute(:initial_state_name)
          name = name.call(self) if name.is_a?(Proc)
          
          name
        end
        
        #
        #
        def initial_state
          self.class.states[initial_state_name.to_s].model
        end
        
        #
        #
        def state_with_initial_check
          state_without_initial_check || (new_record? ? initial_state : nil)
        end
        
        #
        #
        def state_id
          read_attribute(:state_id) || (new_record? ? state.id : nil)
        end
        
        # The current state the object is in
        # 
        def state_name
          state.name
        end
        
        # Returns what the next state for a given event would be, as a Ruby symbol.
        # 
        def next_state_for_event(event_name)
          next_states = next_states_for_event(event_name)
          next_states.empty? ? nil : next_states.first.to
        end
        
        # Returns all of the next possible states for a given event, as Ruby symbols.
        # 
        def next_states_for_event(event_name)
          self.class.transitions[event_name.to_s].select do |transition|
            transition.from == state_name
          end
        end
        
        #
        #
        def record_transition(event_name, from_state_name, to_state_name)
          from_model = self.class.states[from_state_name].model if from_state_name
          to_model = self.class.states[to_state_name].model
          
          state_attrs = {
            :to_state_id => to_model.id,
            :occurred_at => Time.now
          }
          state_attrs[:event_id] = self.class.events[event_name].id if event_name
          state_attrs[:from_state_id] = from_model.id if from_model
          
          state_changes.create(state_attrs)
          
          if self.class.use_state_deadlines && send("#{to_state_name}_deadline")
            send("clear_#{to_state_name}_deadline")
          end
        end
        
        #
        #
        def after_find
          check_deadlines
        end
        
        #
        #
        def check_deadlines(options = {})
          transitioned = false
          
          if self.class.use_state_deadlines
            current_deadline = send("#{state_name}_deadline")
            
            if current_deadline && current_deadline <= Time.now
              state = self.class.states[state_name]
              transitioned = send(state.deadline_passed_event, options)
            end
          end
          
          transitioned
        end
        
        private
        #
        #
        def set_initial_state_id
          self.state_id = state.id if read_attribute(:state_id).nil?
        end
        
        #
        #
        def run_initial_state_actions
          if state_changes.empty?
            transaction(self) do
              state = self.class.states[initial_state_name.to_s]
              state.entering(self)
              state.entered(self)
              
              record_transition(nil, nil, state.name)
            end
          end
        end
        
        #
        #
        def run_transition_action(action)
          Symbol === action ? send(action) : action.call(self)
        end
      end
      
      module ClassMethods
        # Returns an array of all known states.
        # 
        def state_names
          states.keys
        end
        
        # Returns an array of all known states.
        # 
        def event_names
          events.keys
        end
        
        # Define an event.  This takes a block which describes all valid transitions
        # for this event.
        #
        # Example:
        #
        # class Order < ActiveRecord::Base
        #   acts_as_state_machine :initial => :open
        #
        #   state :open
        #   state :closed
        #
        #   event :close_order do
        #     transitions :to => :closed, :from => :open
        #   end
        # end
        #
        # +transitions+ takes a hash where <tt>:to</tt> is the state to transition
        # to and <tt>:from</tt> is a state (or Array of states) from which this
        # event can be fired.
        #
        # This creates an instance method used for firing the event.  The method
        # created is the name of the event followed by an exclamation point (!).
        # Example: <tt>order.close_order!</tt>.
        # 
        def event(name, options = {}, &block)
          name = name.to_s
          model = self::Event.find_by_name(name)
          raise InvalidEvent, "#{name} is not a valid event for #{self.name}" unless model
          
          if event = events[name]
            event.instance_eval(&block) if block
          else
            events[name] = SupportingClasses::Event.new(model, options, transitions, state_names, &block)
            
            class_eval <<-EOV
              def #{name}!(options = {})
                run_initial_state_actions if new_record?
                
                success = false
                transaction(self) do
                  event = self.events['#{name}']
                  if success = event.fire(self, options)
                    success = save if !new_record?
                  end
                  
                  rollback if !success
                end
                
                success
              end
            EOV
          end
        end
        
        # Define a state of the system. +state+ can take an optional Proc object
        # which will be executed every time the system transitions into that
        # state.  The proc will be passed the current object.
        #
        # Example:
        #
        # class Order < ActiveRecord::Base
        #   acts_as_state_machine :initial => :open
        #
        #   state :open
        #   state :closed, Proc.new { |o| Mailer.send_notice(o) }
        # end
        # 
        def state(name, options = {})
          name = name.to_s
          model = self::State.find_by_name(name)
          raise InvalidState, "#{name} is not a valid state for #{self.name}" unless model
          
          states[name] = SupportingClasses::State.new(model, options)
          
          class_eval <<-EOV
            def #{name}?
              state_id == #{model.id}
            end
            
            def #{name}_at
              state_change = state_changes.find_by_to_state_id(#{model.id}, :order => 'occurred_at DESC')
              state_change.occurred_at if !state_change.nil?
            end
          EOV
          
          # Add support for checking deadlines
          if use_state_deadlines
            class_eval <<-EOV
              def #{name}_deadline
                state_deadline = state_deadlines.find_by_state_id(#{model.id})
                state_deadline.deadline if state_deadline
              end
              
              def #{name}_deadline=(value)
                state_deadlines.create(:state_id => #{model.id}, :deadline => value)
              end
              
              def clear_#{name}_deadline
                state_deadlines.find_by_state_id(#{model.id}).destroy
              end
            EOV
          end
          
          self::StateExtension.module_eval <<-EOV
            def #{name}(*args)
              find_all_by_state_id(#{model.id}, *args)
            end
          EOV
        end
        
        # Wraps ActiveRecord::Base.find to conveniently find all records in
        # a given set of states.  Options:
        #
        # * +number+ - This is just :first or :all from ActiveRecord +find+
        # * +state+ - The state to find
        # * +args+ - The rest of the args are passed down to ActiveRecord +find+
        # 
        def find_in_states(number, state_names, *args)
          with_state_scope(state_names) do
            find(number, *args)
          end
        end
        
        # Wraps ActiveRecord::Base.count to conveniently count all records in
        # a given set of states.  Options:
        #
        # * +states+ - The states to find
        # * +args+ - The rest of the args are passed down to ActiveRecord +find+
        # 
        def count_in_states(state_names, *args)
          with_state_scope(state_names) do
            count(*args)
          end
        end
        
        # Wraps ActiveRecord::Base.calculate to conveniently calculate all records in
        # a given set of states.  Options:
        #
        # * +states+ - The states to find
        # * +args+ - The rest of the args are passed down to ActiveRecord +calculate+
        # 
        def calculate_in_state(state_names, *args)
          with_state_scope(state_names) do
            calculate(*args)
          end
        end
        
        #
        #
        def with_state_scope(state_names)
          state_ids = Array(state_names).collect do |name|
            name = name.to_s
            raise InvalidState, "#{name} is not a valid state for #{self.name}" unless states.include?(name)
            
            states[name].id
          end
          
          if state_ids.size == 1
            state_conditions = ['state_id = ?', state_ids.first]
          else
            state_conditions = ['state_id IN (?)', state_ids]
          end
          
          with_scope(:find => {:conditions => state_conditions}) do
            yield
          end
        end
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include PluginAWeek::Acts::StateMachine
end