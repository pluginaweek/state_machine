require 'class_associations'
#require 'dry_transaction_rollbacks'
require 'eval_call'

require 'has_states/invalid_state'
require 'has_states/invalid_event'
require 'has_states/no_initial_state'
require 'has_states/state'
require 'has_states/state_transition'
require 'has_states/event'

module PluginAWeek #:nodoc:
  module Has #:nodoc:
    # A state machine is a model of behavior composed of states, transitions,
    # and events.
    # 
    # Parts of definitions courtesy of http://en.wikipedia.org/wiki/Finite_state_machine.
    # 
    # Switch example:
    # 
    #   class Switch < ActiveRecord::Base
    #     acts_as_state_machine :initial => :off
    #     
    #     state :off
    #     state :on
    #     
    #     event :turn_on do
    #       transition_to :on, :from => :off
    #     end
    #     
    #     event :turn_off do
    #       transition_to :off, :from => :on
    #     end
    #   end
    module States
      class BogusModel < ActiveRecord::Base #:nodoc:
      end
      
      # Migrates the database up by adding a state_id column to the model's
      # table
      def self.migrate_up(model)
        if !model.is_a?(Class)
          BogusModel.set_table_name(model.to_s)
          model = BogusModel
        end
        
        if !model.content_columns.any? {|c| c.name == :state_id}
          model.connection.add_column(model.table_name, :state_id, :integer, :null => false, :default => nil, :unsigned => true)
        end
      end
      
      # Migrates the database down by removing the state_id column from the
      # model's table
      def self.migrate_down(model)
        if !model.is_a?(Class)
          BogusModel.set_table_name(model.to_s)
          model = BogusModel
        end
        
        model.connection.remove_column(model.table_name, :state_id)
      end
      
      def self.included(base) #:nodoc:
        base.extend(MacroMethods)
      end
      
      module MacroMethods
        # Configuration options:
        # * <tt>initial</tt> - The initial state to place each record in.  This can either be a string/symbol or a Proc for dynamic initial states.
        # * <tt>deadlines</tt> - Whether or not deadlines will be used for states.
        def has_states(options)
          options.assert_valid_keys(
            :initial,
            :deadlines
          )
          raise NoInitialState unless options[:initial]
          
          options.reverse_merge!(:deadlines => false)
          
          write_inheritable_attribute :valid_states, {}
          write_inheritable_attribute :initial_state_name, options[:initial]
          write_inheritable_attribute :valid_events, {}
          write_inheritable_attribute :use_state_deadlines, options[:deadlines]
          
          class_inheritable_reader    :valid_states
          class_inheritable_reader    :valid_events
          class_inheritable_reader    :use_state_deadlines
          
          before_create               :set_initial_state_id
          after_create                :run_initial_state_actions
          
          # Create the extension that can be used with association collections
          # like has_many
          const_set('StateExtension', Module.new).class_eval do
            def find_in_states(number, state_names, *args)
              @reflection.klass.with_state_scope(state_names) do
                find(number, *args)
              end
            end
          end
          
          belongs_to  :state
          has_many    :state_changes,
                        :as => :stateful,
                        :dependent => :destroy
          has_many    :state_deadlines,
                        :as => :stateful,
                        :dependent => :destroy if use_state_deadlines
          
          class << self
            has_many  :states,
                        :include_superclasses => true
            has_many  :events,
                        :include_superclasses => true
            has_many  :state_changes,
                        :as => :stateful
            has_many  :state_deadlines,
                        :as => :stateful
            
            # Deprecate errors from Rails 1.2.* force us to remove the method
            remove_method(:find_in_states) if method_defined?(:find_in_states)
          end
          
          extend PluginAWeek::Has::States::ClassMethods
          include PluginAWeek::Has::States::InstanceMethods
        end
      end
      
      module ClassMethods
        def self.extended(base) #:nodoc:
          class << base
            alias inherited_without_association_classes inherited
            alias inherited inherited_with_association_classes
          end
        end
        
        # Adds the proper associations and nested classes
        def inherited_with_association_classes(subclass)
          inherited_without_association_classes(subclass) if respond_to?(:inherited_without_association_classes)
          
          # Create copies of the parent::Events because their valid state names
          # depend on which class its in
          subclass.valid_events.each do |name, event|
            event = event.dup
            event.klass = subclass
            subclass.valid_events[name] = event
          end
        end
        
        # Returns an array of the names of all known states.
        def valid_state_names
          valid_states.keys
        end
        
        # Finds all records that are in a given set of states.
        # 
        # Options:
        # * +number+ - :first or :all
        # * +state_names+ - A state name or list of state names to find
        # * +args+ - The rest of the args are passed down to ActiveRecord +find+
        def find_in_states(number, *args)
          with_state_scope(args) do |options|
            find(number, options)
          end
        end
        alias_method :find_in_state, :find_in_states
        
        # Counts all records in a given set of states.
        # 
        # Options:
        # * +state_names+ - A state name or list of state names to find
        # * +args+ - The rest of the args are passed down to ActiveRecord +find+
        def count_in_states(*args)
          with_state_scope(args) do |options|
            count(options)
          end
        end
        alias_method :count_in_state, :count_in_states
        
        # Calculates all records in a given set of states.
        # 
        # Options:
        # * +state_names+ - A state name or list of state names to find
        # * +args+ - The rest of the args are passed down to ActiveRecord +calculate+
        def calculate_in_states(operation, column_name, *args)
          with_state_scope(args) do |options|
            calculate(operation, column_name, options)
          end
        end
        alias_method :calculate_in_state, :calculate_in_states
        
        # Creates a :find scope for matching certain state names.  We can't use
        # the cached records or check if the states are real because subclasses
        # which add additional states may not necessarily have been added yet.
        def with_state_scope(state_names)
          options = Hash === state_names.last ? state_names.pop : {}
          state_names = Array(state_names).map(&:to_s)
          if state_names.size == 1
            state_conditions = ['states.name = ?', state_names.first]
          else
            state_conditions = ['states.name IN (?)', state_names]
          end
          
          with_scope(:find => {:include => :state, :conditions => state_conditions}) do
            yield options
          end
        end
        
        # Returns an array of all known states.
        def valid_event_names
          valid_events.keys
        end
        
        private  
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
        def state(*names)
          options = names.last.is_a?(Hash) ? names.pop : {}
          
          names.each do |name|
            name = name.to_sym
            record = states.find_by_name(name.to_s)
            raise InvalidState, "#{name} is not a valid state for #{self.name}" unless record
            
            valid_states[name] = parent::State.new(record, options)
            
            class_eval <<-end_eval
              def #{name}?
                state_id == #{record.id}
              end
              
              def #{name}_at
                state_change = state_changes.find_by_to_state_id(#{record.id}, :order => 'occurred_at DESC')
                state_change.occurred_at if state_change
              end
            end_eval
            
            # Add support for checking deadlines
            if use_state_deadlines
              class_eval <<-end_eval
                def #{name}_deadline
                  state_deadline = state_deadlines.find_by_state_id(#{record.id})
                  state_deadline.deadline if state_deadline
                end
                
                def #{name}_deadline_passed?
                  state_deadline = state_deadlines.find_by_state_id(#{record.id})
                  state_deadline && state_deadline.passed?
                end
                
                def #{name}_deadline=(value)
                  state_deadline = state_deadlines.find_or_initialize_by_state_id(#{record.id})
                  state_deadline.stateful = self
                  state_deadline.deadline = value
                  state_deadline.save!
                end
                
                def clear_#{name}_deadline
                  state_deadlines.find_by_state_id(#{record.id}).destroy
                end
              end_eval
            end
            
            self::StateExtension.module_eval <<-end_eval
              def #{name}(*args)
                with_scope(:find => {:conditions => ["\#{aliased_table_name}.state_id = ?", #{record.id}]}) do
                  find(args.first.is_a?(Symbol) ? args.shift : :all, *args)
                end
              end
              
              def #{name}_count(*args)
                with_scope(:find => {:conditions => ["\#{aliased_table_name}.state_id = ?", #{record.id}]}) do
                  count(*args)
                end
              end
          end_eval
          end
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
        def event(name, options = {}, &block)
          name = name.to_sym
          
          if event = valid_events[name]
            # The event has already been defined, so just evaluate the new
            # block
            event.instance_eval(&block) if block
          else
            record = events.find_by_name(name.to_s)
            raise InvalidEvent, "#{name} is not a valid event for #{self.name}" unless record
            
            valid_events[name] = parent::Event.new(record, options, self, &block)
            
            # Add action for transitioning the model
            class_eval <<-end_eval
              def #{name}!(*args)
                success = false
                transaction do
                  save! if new_record?
                  
                  if self.class.valid_events[:#{name.to_s.dump}].fire(self, *args)
                    success = save!
                  else
                    rollback
                  end
                end
                
                success
              end
            end_eval
          end
        end
      end
      
      module InstanceMethods
        def self.included(base) #:nodoc:
          base.class_eval do
            alias_method_chain :state, :initial_check
          end
        end
        
        # Gets the name of the initial state that records will be placed in.
        def initial_state_name
          name = self.class.read_inheritable_attribute(:initial_state_name)
          name = name.call(self) if name.is_a?(Proc)
          
          name.to_sym
        end
        
        # Gets the actual State record for the initial state
        def initial_state
          self.class.valid_states[initial_state_name].record
        end
        
        # Gets the state of the record.  If this record has not been saved, then
        # the initial state will be returned.
        def state_with_initial_check
          state_without_initial_check || (new_record? ? initial_state : nil)
        end
        
        # Gets the state id of the record.  If this record has not been saved,
        # then the id of the initial state will be returned.
        def state_id
          read_attribute(:state_id) || (new_record? ? state.id : nil)
        end
        
        # The name of the current state the object is in
        def state_name
          state.name
        end
        
        # Returns what the next state for a given event would be, as a Ruby symbol.
        def next_state_for_event(name)
          next_states = next_states_for_event(name)
          next_states.empty? ? nil : next_states.first
        end
        
        # Returns all of the next possible states for a given event, as Ruby symbols.
        def next_states_for_event(name)
          event = self.class.valid_events[name.to_sym]
          raise InvalidEvent, "#{name} is not a valid event for #{self.class.name}" unless event
          
          event.next_states_for(self).map(&:to_name)
        end
        
        private
        # Records the state change in the database
        def record_transition(event_name, from_state_name, to_state_name)
          from_record = self.class.valid_states[from_state_name].record if from_state_name
          to_record = self.class.valid_states[to_state_name].record
          
          state_attrs = {
            :to_state_id => to_record.id,
            :occurred_at => Time.now
          }
          state_attrs[:event_id] = self.class.valid_events[event_name].id if event_name
          state_attrs[:from_state_id] = from_record.id if from_record
          
          state_change = state_changes.build(state_attrs)
          state_change.save!
          
          # If a deadline already existed for the state, then clear it so that
          # we can generate a new one
          # TODO: This doesn't work
#          if self.class.use_state_deadlines && send("#{to_state_name}_deadline")
#            send("clear_#{to_state_name}_deadline")
#          end
        end
        
        # Ensures that deadlines are checked after a record has been retrieved
        # from the database
        def after_find
          check_deadlines
        end
        
        # Checks that the deadline hasn't passed for the current state of the
        # record
        def check_deadlines
          transitioned = false
          
          if self.class.use_state_deadlines
            current_deadline = send("#{state_name}_deadline")
            
            if current_deadline && current_deadline <= Time.now
              state = self.class.valid_states[state_name]
              transitioned = send(state.deadline_passed_event)
            end
          end
          
          transitioned
        end
        
        # Sets the initial state id of the record so long as it hasn't already
        # been set
        def set_initial_state_id
          self.state_id = state.id if read_attribute(:state_id).nil?
        end
        
        # Records the transition for the record going into its initial state
        def run_initial_state_actions
          if state_changes.empty?
            transaction do
              state = self.class.valid_states[initial_state_name]
              state.before_enter(self)
              state.after_enter(self)
              
              record_transition(nil, nil, state.name)
            end
          end
        end
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include PluginAWeek::Has::States
end
