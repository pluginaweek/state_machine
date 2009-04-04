module StateMachine
  module Integrations #:nodoc:
    # Adds support for integrating state machines with ActiveRecord models.
    # 
    # == Examples
    # 
    # Below is an example of a simple state machine defined within an
    # ActiveRecord model:
    # 
    #   class Vehicle < ActiveRecord::Base
    #     state_machine :initial => :parked do
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #   end
    # 
    # The examples in the sections below will use the above class as a
    # reference.
    # 
    # == Actions
    # 
    # By default, the action that will be invoked when a state is transitioned
    # is the +save+ action.  This will cause the record to save the changes
    # made to the state machine's attribute.  *Note* that if any other changes
    # were made to the record prior to transition, then those changes will
    # be saved as well.
    # 
    # For example,
    # 
    #   vehicle = Vehicle.create          # => #<Vehicle id: 1, name: nil, state: "parked">
    #   vehicle.name = 'Ford Explorer'
    #   vehicle.ignite                    # => true
    #   vehicle.reload                    # => #<Vehicle id: 1, name: "Ford Explorer", state: "idling">
    # 
    # == Events
    # 
    # As described in StateMachine::InstanceMethods#state_machine, event
    # attributes are created for every machine that allow transitions to be
    # performed automatically when the object's action (in this case, :save)
    # is called.
    # 
    # In ActiveRecord, these automated events are run in the following order:
    # * before validation - Run before callbacks and persist new states, then validate
    # * before save - If validation was skipped, run before callbacks and persist new states, then save
    # * after save - Run after callbacks
    # 
    # For example,
    # 
    #   vehicle = Vehicle.create          # => #<Vehicle id: 1, name: nil, state: "parked">
    #   vehicle.state_event               # => nil
    #   vehicle.state_event = 'invalid'
    #   vehicle.valid?                    # => false
    #   vehicle.errors.full_messages      # => ["State event is invalid"]
    #   
    #   vehicle.state_event = 'ignite'
    #   vehicle.valid?                    # => true
    #   vehicle.save                      # => true
    #   vehicle.state                     # => "idling"
    #   vehicle.state_event               # => nil
    # 
    # Note that this can also be done on a mass-assignment basis:
    # 
    #   vehicle = Vehicle.create(:state_event => 'ignite')  # => #<Vehicle id: 1, name: nil, state: "idling">
    #   vehicle.state                                       # => "idling"
    # 
    # == Transactions
    # 
    # In order to ensure that any changes made during transition callbacks
    # are rolled back during a failed attempt, every transition is wrapped
    # within a transaction.
    # 
    # For example,
    # 
    #   class Message < ActiveRecord::Base
    #   end
    #   
    #   Vehicle.state_machine do
    #     before_transition do |vehicle, transition|
    #       Message.create(:content => transition.inspect)
    #       false
    #     end
    #   end
    #   
    #   vehicle = Vehicle.create      # => #<Vehicle id: 1, name: nil, state: "parked">
    #   vehicle.ignite                # => false
    #   Message.count                 # => 0
    # 
    # *Note* that only before callbacks that halt the callback chain and
    # failed attempts to save the record will result in the transaction being
    # rolled back.  If an after callback halts the chain, the previous result
    # still applies and the transaction is *not* rolled back.
    # 
    # To turn off transactions:
    # 
    #   class Vehicle < ActiveRecord::Base
    #     state_machine :initial => :parked, :use_transactions => false do
    #       ...
    #     end
    #   end
    # 
    # == Validation errors
    # 
    # If an event fails to successfully fire because there are no matching
    # transitions for the current record, a validation error is added to the
    # record's state attribute to help in determining why it failed and for
    # reporting via the UI.
    # 
    # For example,
    # 
    #   vehicle = Vehicle.create(:state => 'idling')  # => #<Vehicle id: 1, name: nil, state: "idling">
    #   vehicle.ignite                                # => false
    #   vehicle.errors.full_messages                  # => ["State cannot transition via \"ignite\""]
    # 
    # If an event fails to fire because of a validation error on the record and
    # *not* because a matching transition was not available, no error messages
    # will be added to the state attribute.
    # 
    # == Scopes
    # 
    # To assist in filtering models with specific states, a series of named
    # scopes are defined on the model for finding records with or without a
    # particular set of states.
    # 
    # These named scopes are essentially the functional equivalent of the
    # following definitions:
    # 
    #   class Vehicle < ActiveRecord::Base
    #     named_scope :with_states, lambda {|*states| {:conditions => {:state => states}}}
    #     # with_states also aliased to with_state
    #     
    #     named_scope :without_states, lambda {|*states| {:conditions => ['state NOT IN (?)', states]}}
    #     # without_states also aliased to without_state
    #   end
    # 
    # *Note*, however, that the states are converted to their stored values
    # before being passed into the query.
    # 
    # Because of the way named scopes work in ActiveRecord, they can be
    # chained like so:
    # 
    #   Vehicle.with_state(:parked).all(:order => 'id DESC')
    # 
    # == Callbacks
    # 
    # All before/after transition callbacks defined for ActiveRecord models
    # behave in the same way that other ActiveRecord callbacks behave.  The
    # object involved in the transition is passed in as an argument.
    # 
    # For example,
    # 
    #   class Vehicle < ActiveRecord::Base
    #     state_machine :initial => :parked do
    #       before_transition any => :idling do |vehicle|
    #         vehicle.put_on_seatbelt
    #       end
    #       
    #       before_transition do |vehicle, transition|
    #         # log message
    #       end
    #       
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #     
    #     def put_on_seatbelt
    #       ...
    #     end
    #   end
    # 
    # Note, also, that the transition can be accessed by simply defining
    # additional arguments in the callback block.
    # 
    # == Observers
    # 
    # In addition to support for ActiveRecord-like hooks, there is additional
    # support for ActiveRecord observers.  Because of the way ActiveRecord
    # observers are designed, there is less flexibility around the specific
    # transitions that can be hooked in.  However, a large number of hooks
    # *are* supported.  For example, if a transition for a record's +state+
    # attribute changes the state from +parked+ to +idling+ via the +ignite+
    # event, the following observer methods are supported:
    # * before/after_ignite_from_parked_to_idling
    # * before/after_ignite_from_parked
    # * before/after_ignite_to_idling
    # * before/after_ignite
    # * before/after_transition_state_from_parked_to_idling
    # * before/after_transition_state_from_parked
    # * before/after_transition_state_to_idling
    # * before/after_transition_state
    # * before/after_transition
    # 
    # The following class shows an example of some of these hooks:
    # 
    #   class VehicleObserver < ActiveRecord::Observer
    #     def before_save(vehicle)
    #       # log message
    #     end
    #     
    #     # Callback for :ignite event *before* the transition is performed
    #     def before_ignite(vehicle, transition)
    #       # log message
    #     end
    #     
    #     # Callback for :ignite event *after* the transition has been performed
    #     def after_ignite(vehicle, transition)
    #       # put on seatbelt
    #     end
    #     
    #     # Generic transition callback *before* the transition is performed
    #     def after_transition(vehicle, transition)
    #       Audit.log(vehicle, transition)
    #     end
    #   end
    # 
    # More flexible transition callbacks can be defined directly within the
    # model as described in StateMachine::Machine#before_transition
    # and StateMachine::Machine#after_transition.
    # 
    # To define a single observer for multiple state machines:
    # 
    #   class StateMachineObserver < ActiveRecord::Observer
    #     observe Vehicle, Switch, Project
    #     
    #     def after_transition(record, transition)
    #       Audit.log(record, transition)
    #     end
    #   end
    module ActiveRecord
      # The default options to use for state machines using this integration
      class << self; attr_reader :defaults; end
      @defaults = {:action => :save}
      
      # Should this integration be used for state machines in the given class?
      # Classes that inherit from ActiveRecord::Base will automatically use
      # the ActiveRecord integration.
      def self.matches?(klass)
        defined?(::ActiveRecord::Base) && klass <= ::ActiveRecord::Base
      end
      
      # Loads additional files specific to ActiveRecord
      def self.extended(base) #:nodoc:
        require 'state_machine/integrations/active_record/observer'
        I18n.load_path << "#{File.dirname(__FILE__)}/active_record/locale.rb" if Object.const_defined?(:I18n)
      end
      
      # Adds a validation error to the given object 
      def invalidate(object, attribute, message, values = [])
        if Object.const_defined?(:I18n)
          options = values.inject({}) {|options, (key, value)| options[key] = value; options}
          object.errors.add(attribute, message, options.merge(
            :default => @messages[message]
          ))
        else
          object.errors.add(attribute, generate_message(message, values))
        end
      end
      
      # Resets any errors previously added when invalidating the given object
      def reset(object)
        object.errors.clear
      end
      
      protected
        # Adds the default callbacks for notifying ActiveRecord observers
        # before/after a transition has been performed.
        def after_initialize
          callbacks[:before] << Callback.new {|object, transition| notify(:before, object, transition)}
          callbacks[:after] << Callback.new {|object, transition| notify(:after, object, transition)}
        end
        
        # Skips defining reader/writer methods since this is done automatically
        def define_state_accessor
        end
        
        # Adds support for defining the attribute predicate, while providing
        # compatibility with the default predicate which determines whether
        # *anything* is set for the attribute's value
        def define_state_predicate
          attribute = self.attribute
          
          # Still use class_eval here instance of define_instance_method since
          # we need to be able to call +super+
          @instance_helper_module.class_eval do
            define_method("#{attribute}?") do |*args|
              args.empty? ? super(*args) : self.class.state_machine(attribute).states.matches?(self, *args)
            end
          end
        end
        
        # Adds hooks into validation for automatically firing events
        def define_action_helpers
          if super && action == :save
            @instance_helper_module.class_eval do
              define_method(:valid?) do |*args|
                self.class.state_machines.fire_attribute_events(self, :save, false) { super(*args) }
              end
            end
          end
        end
        
        # Creates a scope for finding records *with* a particular state or
        # states for the attribute
        def create_with_scope(name)
          attribute = self.attribute
          define_scope(name, lambda {|values| {:conditions => {attribute => values}}})
        end
        
        # Creates a scope for finding records *without* a particular state or
        # states for the attribute
        def create_without_scope(name)
          attribute = self.attribute
          define_scope(name, lambda {|values| {:conditions => ["#{attribute} NOT IN (?)", values]}})
        end
        
        # Runs a new database transaction, rolling back any changes by raising
        # an ActiveRecord::Rollback exception if the yielded block fails
        # (i.e. returns false).
        def transaction(object)
          object.class.transaction {raise ::ActiveRecord::Rollback unless yield}
        end
        
        # Creates a new callback in the callback chain, always inserting it
        # before the default Observer callbacks that were created after
        # initialization.
        def add_callback(type, options, &block)
          options[:terminator] = @terminator ||= lambda {|result| result == false}
          @callbacks[type].insert(-2, callback = Callback.new(options, &block))
          add_states(callback.known_states)
          
          callback
        end
        
      private
        # Defines a new named scope with the given name.  Since ActiveRecord
        # does not allow direct access to the model being used within the
        # evaluation of a dynamic named scope, the scope must be generated
        # manually.  It's necessary to have access to the model so that the
        # state names can be translated to their associated values and so that
        # inheritance is respected properly.
        def define_scope(name, scope)
          name = name.to_sym
          attribute = self.attribute
          
          # Created the scope and then override it with state translation
          owner_class.named_scope(name)
          owner_class.scopes[name] = lambda do |klass, *states|
            machine_states = klass.state_machine(attribute).states
            values = states.flatten.map {|state| machine_states.fetch(state).value}
            
            ::ActiveRecord::NamedScope::Scope.new(klass, scope.call(values))
          end
          
          false
        end
        
        # Notifies observers on the given object that a callback occurred
        # involving the given transition.  This will attempt to call the
        # following methods on observers:
        # * #{type}_#{qualified_event}_from_#{from}_to_#{to}
        # * #{type}_#{qualified_event}_from_#{from}
        # * #{type}_#{qualified_event}_to_#{to}
        # * #{type}_#{qualified_event}
        # * #{type}_transition_#{attribute}_from_#{from}_to_#{to}
        # * #{type}_transition_#{attribute}_from_#{from}
        # * #{type}_transition_#{attribute}_to_#{to}
        # * #{type}_transition_#{attribute}
        # * #{type}_transition
        # 
        # This will always return true regardless of the results of the
        # callbacks.
        def notify(type, object, transition)
          attribute = transition.attribute
          event = transition.qualified_event
          from = transition.from_name
          to = transition.to_name
          
          # Machine-specific updates
          ["#{type}_#{event}", "#{type}_transition_#{attribute}"].each do |event_segment|
            ["_from_#{from}", nil].each do |from_segment|
              ["_to_#{to}", nil].each do |to_segment|
                object.class.changed
                object.class.notify_observers([event_segment, from_segment, to_segment].join, object, transition)
              end
            end
          end
          
          # Generic updates
          object.class.changed
          object.class.notify_observers("#{type}_transition", object, transition)
          
          true
        end
    end
  end
end
