require 'class_associations'
require 'dry_transaction_rollbacks' unless defined?(ActiveRecord::Rollback) # Support on edge
require 'eval_call'

require 'has_states/active_state'
require 'has_states/state_transition'
require 'has_states/active_event'
require 'has_states/state_extension'

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
      class StatefulModel < ActiveRecord::Base #:nodoc:
      end
      
      # An unknown state was specified
      class StateNotFound < StandardError #:nodoc:
      end
      
      # An inactive state was specified
      class StateNotActive < StandardError #:nodoc:
      end
      
      # An unknown event was specified
      class EventNotFound < StandardError #:nodoc:
      end
      
      # An inactive state was specified
      class EventNotActive < StandardError #:nodoc:
      end
      
      # No initial state was specified for the machine
      class NoInitialState < StandardError #:nodoc:
      end
      
      class << self
        # Migrates up the model's table by adding support for states
        def migrate_up(model)
          if !model.is_a?(Class)
            StatefulModel.set_table_name(model.to_s)
            model = StatefulModel
          end
          
          if !model.column_names.include?(:state_id)
            ActiveRecord::Base.connection.add_column(model.table_name, :state_id, :integer, :null => false, :default => nil, :unsigned => true)
          end
        end
        
        # Migrates the database down by removing support for states
        def migrate_down(model)
          if !model.is_a?(Class)
            StatefulModel.set_table_name(model.to_s)
            model = StatefulModel
          end
          
          ActiveRecord::Base.connection.remove_column(model.table_name, :state_id)
        end
        
        def included(base) #:nodoc:
          base.extend(MacroMethods)
        end
      end
      
      module MacroMethods
        # Configuration options:
        # * <tt>initial</tt> - The initial state to place each record in.  This can either be a string/symbol or a Proc for dynamic initial states.
        # * <tt>track</tt> - Whether or not to track changes to the model's state
        def has_states(options)
          options.assert_valid_keys(
            :initial,
            :record_changes
          )
          raise NoInitialState unless options[:initial]
          
          options.reverse_merge!(:record_changes => true)
          
          # Save options for referencing later
          write_inheritable_attribute :active_states, {}
          write_inheritable_attribute :active_events, {}
          write_inheritable_attribute :initial_state_name, options[:initial]
          write_inheritable_attribute :record_state_changes, options[:record_changes]
          
          class_inheritable_reader    :active_states
          class_inheritable_reader    :active_events
          class_inheritable_reader    :record_state_changes
          
          before_create               :set_initial_state_id
          after_create                :run_initial_state_actions
          
          # Create the extension that can be used with association collections
          # like has_many
          const_set('StateExtension', StateExtension.dup)
          
          belongs_to  :state
          has_many    :state_changes,
                        :as => :stateful,
                        :dependent => :destroy if record_state_changes
          
          class << self
            has_many  :states,
                        :include_superclasses => true
            has_many  :events,
                        :include_superclasses => true
            has_many  :state_changes,
                        :as => :stateful if record_state_changes
            
            # Deprecate errors from Rails 1.2.* force us to remove the method
            remove_method(:find_in_states) if method_defined?(:find_in_states)
          end
          
          State.class_eval <<-end_eval
            has_many :#{self.to_s.tableize}, :extend => #{self}::StateExtension
          end_eval
          
          extend PluginAWeek::Has::States::ClassMethods
          include PluginAWeek::Has::States::InstanceMethods
        end
      end
      
      module ClassMethods
        def self.extended(base) #:nodoc:
          class << base
            alias_method_chain :inherited, :states
          end
        end
        
        def inherited_with_states(subclass) #:nodoc:
          inherited_without_states(subclass)
          
          # Update the active events to point to the new subclass
          subclass.active_events.each do |name, event|
            event = event.dup
            event.owner_type = subclass.name
            subclass.active_events[name] = event
          end
          
          # Create a new state extension class for the subclass
          subclass.const_set('StateExtension', subclass.superclass::StateExtension.dup)
        end
        
        # Checks whether the given name is an active state in the system
        def active_state?(name)
          active_states.keys.include?(name.to_sym)
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
        # * +operation+ - What operation to use to calculate the value
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
        def with_state_scope(args)
          options = extract_options_from_args!(args)
          state_names = Array(args).map(&:to_s)
          if state_names.size == 1
            state_conditions = ['states.name = ?', state_names.first]
          else
            state_conditions = ['states.name IN (?)', state_names]
          end
          
          with_scope(:find => {:include => :state, :conditions => state_conditions}) do
            yield options
          end
        end
        
        # Checks whether the given name is an active event in the system
        def active_event?(name)
          active_events.keys.include?(name.to_sym)
        end
        
        private
        # Definse a state of the system. +names+ can take an optional hash
        # that defines callbacks which should be invoked when the object enters/
        # exits the state.
        #
        # Example:
        #
        # class Car < ActiveRecord::Base
        #   acts_as_state_machine :initial => :parked
        #
        #   state :parked, :idling
        #   state :first_gear, :before_enter => :put_on_seatbelt
        # end
        def state(*names)
          options = extract_options_from_args!(names)
          
          names.each do |name|
            name = name.to_sym
            state = states.find_by_name(name.to_s, :readonly => true)
            raise StateNotFound, "Couldn't find #{self.name} state with name=#{name.to_s.inspect}" unless state
            
            state.extend PluginAWeek::Has::States::ActiveState
            active_states[name] = state
            
            # Add checking the current state
            class_eval <<-end_eval
              def #{name}?
                state_id == #{state.id}
              end
            end_eval
            
            # Add checking when the change in state occurred
            if record_state_changes
              class_eval <<-end_eval
                def #{name}_at(count = :last)
                  if [:first, :last].include?(count)
                    state_change = state_changes.find_by_to_state_id(#{state.id}, :order => "occurred_at \#{count == :first ? 'ASC' : 'DESC'}")
                    state_change.occurred_at if state_change
                  else
                    state_changes.find_all_by_to_state_id(#{state.id}, :order => 'occurred_at ASC').map(&:occurred_at)
                  end
                end
              end_eval
            end
            
            # Add callbacks
            [:before_enter, :after_enter, :before_exit, :after_exit].each do |callback|
              class_eval <<-end_eval
                def self.#{callback}_#{name}(*callbacks, &block)
                  callbacks << block if block_given?
                  write_inheritable_array(:#{callback}_#{name}, callbacks)
                end
              end_eval
              
              send("#{callback}_#{name}", options[callback]) if options[callback]
            end
            
            # Update the state extension module to support looking up records
            # of this object by state in a has_many association
            self::StateExtension.module_eval <<-end_eval
              def #{name}(*args)
                with_scope(:find => {:conditions => ["\#{aliased_table_name}.state_id = ?", #{state.id}]}) do
                  find(args.first.is_a?(Symbol) ? args.shift : :all, *args)
                end
              end
              
              def #{name}_count(*args)
                with_scope(:find => {:conditions => ["\#{aliased_table_name}.state_id = ?", #{state.id}]}) do
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
          options.assert_valid_keys(:after)
          
          if event = active_events[name]
            # The event has already been defined, so just evaluate the new block
            event.instance_eval(&block) if block
          else
            event = events.find_by_name(name.to_s, :readonly => true)
            raise EventNotFound, "Couldn't find #{self.name} state with name=#{name.to_s.inspect}" unless event
            
            event.extend PluginAWeek::Has::States::ActiveEvent
            active_events[name] = event
            event.instance_eval(&block) if block
            
            class_eval <<-end_eval
              # Add action for transitioning the model
              def #{name}!(*args)
                success = false
                transaction do
                  save! if new_record?
                  
                  if self.class.active_events[:#{name.to_s.dump}].fire(self, *args)
                    success = save!
                  else
                    raise ActiveRecord::Rollback
                  end
                end
                
                success
              end
              
              # Add callbacks
              def self.after_#{name}(*callbacks, &block)
                callbacks << block if block_given?
                active_events[:#{name}].callbacks.concat(callbacks)
              end
            end_eval
          end
          
          event.callbacks << options[:after] if options[:after]
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
        
        # Gets the actual record for the initial state
        def initial_state
          self.class.active_states[initial_state_name]
        end
        
        # Gets the state of the record.  If this record has not been saved, then
        # the initial state will be returned.
        def state_with_initial_check
          state_without_initial_check || (new_record? ? initial_state : nil)
        end
        
        # Gets the state id of the record.  If this record has not been saved,
        # then the id of the initial state will be returned.
        def state_id
          read_attribute(:state_id) || (new_record? ? initial_state.id : nil)
        end
        
        # Returns what the next state for a given event would be, as a Ruby symbol
        def next_state_for_event(name)
          next_states = next_states_for_event(name)
          next_states.empty? ? nil : next_states.first
        end
        
        # Returns all of the next possible states for a given event, as Ruby symbols.
        def next_states_for_event(name)
          event = self.class.active_events[name.to_sym]
          raise StateNotActive, "Couldn't find active #{self.class.name} state with name=#{name.to_s.inspect}" unless event
          
          event.possible_transitions_from(self.state).map(&:to_state)
        end
        
        private
        # Records the state change in the database
        def record_state_change(event, from_state, to_state)
          if self.class.record_state_changes
            state_change = state_changes.build
            state_change.to_state = to_state
            state_change.from_state = from_state if from_state
            state_change.event = event if event
            
            state_change.save!
          end
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
              state = self.class.active_states[initial_state_name]
              callback("after_enter_#{state.name}")
              
              record_state_change(nil, nil, state)
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
