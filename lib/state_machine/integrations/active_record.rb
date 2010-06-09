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
    # This technique is always used for transitioning states when the +save+
    # action (which is the default) is configured for the machine.
    # 
    # === Security implications
    # 
    # Beware that public event attributes mean that events can be fired
    # whenever mass-assignment is being used.  If you want to prevent malicious
    # users from tampering with events through URLs / forms, the attribute
    # should be protected like so:
    # 
    #   class Vehicle < ActiveRecord::Base
    #     attr_protected :state_event
    #     # attr_accessible ... # Alternative technique
    #     
    #     state_machine do
    #       ...
    #     end
    #   end
    # 
    # If you want to only have *some* events be able to fire via mass-assignment,
    # you can build two state machines (one public and one protected) like so:
    # 
    #   class Vehicle < ActiveRecord::Base
    #     attr_protected :state_event # Prevent access to events in the first machine
    #     
    #     state_machine do
    #       # Define private events here
    #     end
    #     
    #     # Public machine targets the same state as the private machine
    #     state_machine :public_state, :attribute => :state do
    #       # Define public events here
    #     end
    #   end
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
    # If using the +save+ action for the machine, this option will be ignored as
    # the transaction will be created by ActiveRecord within +save+.
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
    # 
    # == Internationalization
    # 
    # In Rails 2.2+, any error message that is generated from performing invalid
    # transitions can be localized.  The following default translations are used:
    # 
    #   en:
    #     activerecord:
    #       errors:
    #         messages:
    #           invalid: "is invalid"
    #           invalid_event: "cannot transition when %{state}"
    #           invalid_transition: "cannot transition via %{event}"
    # 
    # Notice that the interpolation syntax is %{key} in Rails 3+.  In Rails 2.x,
    # the appropriate syntax is {{key}}.
    # 
    # You can override these for a specific model like so:
    # 
    #   en:
    #     activerecord:
    #       errors:
    #         models:
    #           user:
    #             invalid: "is not valid"
    # 
    # In addition to the above, you can also provide translations for the
    # various states / events in each state machine.  Using the Vehicle example,
    # state translations will be looked for using the following keys:
    # * <tt>activerecord.state_machines.vehicle.state.states.parked</tt>
    # * <tt>activerecord.state_machines.state.states.parked
    # * <tt>activerecord.state_machines.states.parked</tt>
    # 
    # Event translations will be looked for using the following keys:
    # * <tt>activerecord.state_machines.vehicle.state.events.ignite</tt>
    # * <tt>activerecord.state_machines.state.events.ignite
    # * <tt>activerecord.state_machines.events.ignite</tt>
    # 
    # An example translation configuration might look like so:
    # 
    #   es:
    #     activerecord:
    #       state_machines:
    #         states:
    #           parked: 'estacionado'
    #         events:
    #           park: 'estacionarse'
    module ActiveRecord
      include ActiveModel
      
      # The default options to use for state machines using this integration
      @defaults = {:action => :save}
      
      # Should this integration be used for state machines in the given class?
      # Classes that inherit from ActiveRecord::Base will automatically use
      # the ActiveRecord integration.
      def self.matches?(klass)
        defined?(::ActiveRecord::Base) && klass <= ::ActiveRecord::Base
      end
      
      def self.extended(base) #:nodoc:
        require 'active_record/version'
        require 'state_machine/integrations/active_model/observer'
        
        ::ActiveRecord::Observer.class_eval do
          include StateMachine::Integrations::ActiveModel::Observer
        end unless ::ActiveRecord::Observer.included_modules.include?(StateMachine::Integrations::ActiveModel::Observer)
        
        if Object.const_defined?(:I18n)
          locale = "#{File.dirname(__FILE__)}/active_record/locale.rb"
          I18n.load_path.unshift(locale) unless I18n.load_path.include?(locale)
        end
      end
      
      # Adds a validation error to the given object 
      def invalidate(object, attribute, message, values = [])
        if Object.const_defined?(:I18n)
          super
        else
          object.errors.add(self.attribute(attribute), generate_message(message, values))
        end
      end
      
      protected
        # Always adds observer support
        def supports_observers?
          true
        end
        
        # Always adds validation support
        def supports_validations?
          true
        end
        
        # Only runs validations on the action if using <tt>:save</tt>
        def runs_validations_on_action?
          action == :save
        end
        
        # Only adds dirty tracking support if ActiveRecord supports it
        def supports_dirty_tracking?(object)
          defined?(::ActiveRecord::Dirty) && object.respond_to?("#{self.attribute}_changed?") || super
        end
        
        # Always uses the <tt>:activerecord</tt> translation scope
        def i18n_scope
          :activerecord
        end
        
        # Attempts to look up a class's ancestors via:
        # * #lookup_ancestors
        # * #self_and_descendants_from_active_record
        # * #self_and_descendents_from_active_record
        def ancestors_for(klass)
          if ::ActiveRecord::VERSION::MAJOR >= 3
            super
          elsif ::ActiveRecord::VERSION::MINOR == 3 && ::ActiveRecord::VERSION::TINY >= 2
            klass.self_and_descendants_from_active_record
          else
            klass.self_and_descendents_from_active_record
          end
        end
        
        # Defines an initialization hook into the owner class for setting the
        # initial state of the machine *before* any attributes are set on the
        # object
        def define_state_initializer
          @instance_helper_module.class_eval <<-end_eval, __FILE__, __LINE__
            # Ensure that the attributes setter gets used to force initialization
            # of the state machines
            def initialize(attributes = nil, *args)
              attributes ||= {}
              super
            end
            
            # Hooks in to attribute initialization to set the states *prior*
            # to the attributes being set
            def attributes=(new_attributes, *args)
              if new_record? && !@initialized_state_machines
                @initialized_state_machines = true
                
                if new_attributes
                  attributes = new_attributes.dup
                  attributes.stringify_keys!
                  ignore = remove_attributes_protected_from_mass_assignment(attributes).keys
                else
                  ignore = []
                end
                
                initialize_state_machines(:dynamic => false, :ignore => ignore)
                super
                initialize_state_machines(:dynamic => true, :ignore => ignore)
              else
                super
              end
            end
          end_eval
        end
        
        # Adds support for defining the attribute predicate, while providing
        # compatibility with the default predicate which determines whether
        # *anything* is set for the attribute's value
        def define_state_predicate
          name = self.name
          
          # Still use class_eval here instance of define_instance_method since
          # we need to be able to call +super+
          @instance_helper_module.class_eval do
            define_method("#{name}?") do |*args|
              args.empty? ? super(*args) : self.class.state_machine(name).states.matches?(self, *args)
            end
          end
        end
        
        # Adds hooks into validation for automatically firing events
        def define_action_helpers
          super(action == :save ? :create_or_update : action)
        end
        
        # Creates a scope for finding records *with* a particular state or
        # states for the attribute
        def create_with_scope(name)
          define_scope(name, lambda {|values| {:conditions => {attribute => values}}})
        end
        
        # Creates a scope for finding records *without* a particular state or
        # states for the attribute
        def create_without_scope(name)
          define_scope(name, lambda {|values|
            connection = owner_class.connection
            {:conditions => ["#{connection.quote_table_name(owner_class.table_name)}.#{connection.quote_column_name(attribute)} NOT IN (?)", values]}
          })
        end
        
        # Runs a new database transaction, rolling back any changes by raising
        # an ActiveRecord::Rollback exception if the yielded block fails
        # (i.e. returns false).
        def transaction(object)
          object.class.transaction {raise ::ActiveRecord::Rollback unless yield}
        end
        
      private
        # Defines a new named scope with the given name
        def define_scope(name, scope)
          if ::ActiveRecord::VERSION::MAJOR >= 3
            lambda {|model, values| model.where(scope.call(values)[:conditions])}
          else
            if owner_class.respond_to?(:named_scope)
              name = name.to_sym
              machine_name = self.name
              
              # Since ActiveRecord does not allow direct access to the model
              # being used within the evaluation of a dynamic named scope, the
              # scope must be generated manually.  It's necessary to have access
              # to the model so that the state names can be translated to their
              # associated values and so that inheritance is respected properly.
              owner_class.named_scope(name)
              owner_class.scopes[name] = lambda do |model, *states|
                machine_states = model.state_machine(machine_name).states
                values = states.flatten.map {|state| machine_states.fetch(state).value}
                
                ::ActiveRecord::NamedScope::Scope.new(model, scope.call(values))
              end
            end
            
            # Prevent the Machine class from wrapping the scope
            false
          end
        end
    end
  end
end
