module StateMachine
  module Integrations #:nodoc:
    # Adds support for integrating state machines with Sequel models.
    # 
    # == Examples
    # 
    # Below is an example of a simple state machine defined within a
    # Sequel model:
    # 
    #   class Vehicle < Sequel::Model
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
    # is the +save+ action.  This will cause the resource to save the changes
    # made to the state machine's attribute.  *Note* that if any other changes
    # were made to the resource prior to transition, then those changes will
    # be made as well.
    # 
    # For example,
    # 
    #   vehicle = Vehicle.create          # => #<Vehicle @values={:state=>"parked", :name=>nil, :id=>1}>
    #   vehicle.name = 'Ford Explorer'
    #   vehicle.ignite                    # => true
    #   vehicle.refresh                   # => #<Vehicle @values={:state=>"idling", :name=>"Ford Explorer", :id=>1}>
    # 
    # == Events
    # 
    # As described in StateMachine::InstanceMethods#state_machine, event
    # attributes are created for every machine that allow transitions to be
    # performed automatically when the object's action (in this case, :save)
    # is called.
    # 
    # In Sequel, these automated events are run in the following order:
    # * before validation - Run before callbacks and persist new states, then validate
    # * before save - If validation was skipped, run before callbacks and persist new states, then save
    # * after save - Run after callbacks
    # 
    # For example,
    # 
    #   vehicle = Vehicle.create          # => #<Vehicle @values={:state=>"parked", :name=>nil, :id=>1}>
    #   vehicle.state_event               # => nil
    #   vehicle.state_event = 'invalid'
    #   vehicle.valid?                    # => false
    #   vehicle.errors.full_messages      # => ["state_event is invalid"]
    #   
    #   vehicle.state_event = 'ignite'
    #   vehicle.valid?                    # => true
    #   vehicle.save                      # => #<Vehicle @values={:state=>"idling", :name=>nil, :id=>1}>
    #   vehicle.state                     # => "idling"
    #   vehicle.state_event               # => nil
    # 
    # Note that this can also be done on a mass-assignment basis:
    # 
    #   vehicle = Vehicle.create(:state_event => 'ignite')  # => #<Vehicle @values={:state=>"idling", :name=>nil, :id=>1}>
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
    #   class Vehicle < Sequel::Model
    #     set_restricted_columns :state_event
    #     # set_allowed_columns ... # Alternative technique
    #     
    #     state_machine do
    #       ...
    #     end
    #   end
    # 
    # If you want to only have *some* events be able to fire via mass-assignment,
    # you can build two state machines (one public and one protected) like so:
    # 
    #   class Vehicle < Sequel::Model
    #     set_restricted_columns :state_event # Prevent access to events in the first machine
    #     
    #     state_machine do
    #       # Define private events here
    #     end
    #     
    #     # Allow both machines to share the same state
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
    #   class Message < Sequel::Model
    #   end
    #   
    #   Vehicle.state_machine do
    #     before_transition do |transition|
    #       Message.create(:content => transition.inspect)
    #       false
    #     end
    #   end
    #   
    #   vehicle = Vehicle.create      # => #<Vehicle @values={:state=>"parked", :name=>nil, :id=>1}>
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
    #   class Vehicle < Sequel::Model
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
    #   vehicle = Vehicle.create(:state => 'idling')  # => #<Vehicle @values={:state=>"parked", :name=>nil, :id=>1}>
    #   vehicle.ignite                                # => false
    #   vehicle.errors.full_messages                  # => ["state cannot transition via \"ignite\""]
    # 
    # If an event fails to fire because of a validation error on the record and
    # *not* because a matching transition was not available, no error messages
    # will be added to the state attribute.
    # 
    # In addition, if you're using the <tt>ignite!</tt> version of the event,
    # then the failure reason (such as the current validation errors) will be
    # included in the exception that gets raised when the event fails.  For
    # example, assuming there's a validation on a field called +name+ on the class:
    # 
    #   vehicle = Vehicle.new
    #   vehicle.ignite!       # => StateMachine::InvalidTransition: Cannot transition state via :ignite from :parked (Reason(s): Name cannot be blank)
    # 
    # == Scopes
    # 
    # To assist in filtering models with specific states, a series of class
    # methods are defined on the model for finding records with or without a
    # particular set of states.
    # 
    # These named scopes are the functional equivalent of the following
    # definitions:
    # 
    #   class Vehicle < Sequel::Model
    #     class << self
    #       def with_states(*states)
    #         filter(:state => states)
    #       end
    #       alias_method :with_state, :with_states
    #       
    #       def without_states(*states)
    #         filter(~{:state => states})
    #       end
    #       alias_method :without_state, :without_states
    #     end
    #   end
    # 
    # *Note*, however, that the states are converted to their stored values
    # before being passed into the query.
    # 
    # Because of the way scopes work in Sequel, they can be chained like so:
    # 
    #   Vehicle.with_state(:parked).order(:id.desc)
    # 
    # Note that states can also be referenced by the string version of their
    # name:
    # 
    #   Vehicle.with_state('parked')
    # 
    # == Callbacks
    # 
    # All before/after transition callbacks defined for Sequel resources
    # behave in the same way that other Sequel hooks behave.  Rather than
    # passing in the record as an argument to the callback, the callback is
    # instead bound to the object and evaluated within its context.
    # 
    # For example,
    # 
    #   class Vehicle < Sequel::Model
    #     state_machine :initial => :parked do
    #       before_transition any => :idling do
    #         put_on_seatbelt
    #       end
    #       
    #       before_transition do |transition|
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
    # === Failure callbacks
    # 
    # +after_failure+ callbacks allow you to execute behaviors when a transition
    # is allowed, but fails to save.  This could be useful for something like
    # auditing transition attempts.  Since callbacks run within transactions in
    # Sequel, a save failure will cause any records that get created in
    # your callback to roll back.  You can work around this issue like so:
    # 
    #   DB = Sequel.connect('mysql://localhost/app')
    #   DB_LOGS = Sequel.connect('mysql://localhost/app')
    #   
    #   class TransitionLog < Sequel::Model(DB_LOGS[:transition_logs])
    #   end
    #   
    #   class Vehicle < Sequel::Model(DB[:vehicles])
    #     state_machine do
    #       after_failure do |transition|
    #         TransitionLog.create(:vehicle => vehicle, :transition => transition)
    #       end
    #       
    #       ...
    #     end
    #   end
    # 
    # The +TransitionLog+ model uses a second connection to the database that
    # allows new records to be saved without being affected by rollbacks in the
    # +Vehicle+ model's transaction.
    # 
    # === Callback Order
    # 
    # Callbacks occur in the following order.  Callbacks specific to state_machine
    # are bolded.  The remaining callbacks are part of Sequel.
    # 
    # * (-) save
    # * (-) begin transaction (if enabled)
    # * (1) *before_transition*
    # * (2) before_validation
    # * (-) validate
    # * (3) after_validation
    # * (4) before_save
    # * (5) before_create
    # * (-) create
    # * (6) after_create
    # * (7) after_save
    # * (8) *after_transition*
    # * (-) end transaction (if enabled)
    # * (9) after_commit
    module Sequel
      include Base
      
      require 'state_machine/integrations/sequel/versions'
      
      # The default options to use for state machines using this integration
      @defaults = {:action => :save}
      
      # Classes that include Sequel::Model will automatically use the Sequel
      # integration.
      def self.matching_ancestors
        %w(Sequel::Model)
      end
      
      # Forces the change in state to be recognized regardless of whether the
      # state value actually changed
      def write(object, attribute, value, *args)
        result = super
        
        column = self.attribute.to_sym
        if (attribute == :state || attribute == :event && value) && owner_class.columns.include?(column) && !object.changed_columns.include?(column)
          object.changed_columns << column
        end
        
        result
      end
      
      # Adds a validation error to the given object
      def invalidate(object, attribute, message, values = [])
        object.errors.add(self.attribute(attribute), generate_message(message, values))
      end
      
      # Describes the current validation errors on the given object.  If none
      # are specific, then the default error is interpeted as a "halt".
      def errors_for(object)
        object.errors.empty? ? 'Transition halted' : object.errors.full_messages * ', '
      end
      
      # Resets any errors previously added when invalidating the given object
      def reset(object)
        object.errors.clear
      end
      
      # Pluralizes the name using the built-in inflector
      def pluralize(word)
        load_inflector
        super
      end
      
      protected
        # Initializes class-level extensions for this machine
        def define_helpers
          load_plugins
          super
        end
        
        # Loads all of the Sequel plugins necessary to run
        def load_plugins
          owner_class.plugin(:hook_class_methods)
        end
        
        # Loads the built-in inflector
        def load_inflector
          require 'sequel/extensions/inflector'
        end
        
        # Defines an initialization hook into the owner class for setting the
        # initial state of the machine *before* any attributes are set on the
        # object
        def define_state_initializer
          define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
            def initialize_set(*)
              self.class.state_machines.initialize_states(self, :static => :force) { super }
            end
          end_eval
        end
        
        # Skips defining reader/writer methods since this is done automatically
        def define_state_accessor
          define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
            def validate(*)
              super
              machine = self.class.state_machine(#{name.inspect})
              machine.invalidate(self, :state, :invalid) unless machine.states.match(self)
            end
          end_eval
        end
        
        # Defines validation hooks if the machine's action is to save the model
        def define_action_helpers
          super
          define_validation_hook if action == :save
        end
        
        # Uses around callbacks to run state events if using the :save hook
        def define_action_hook
          if action == :save
            define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
              def #{action_hook}(*args)
                opts = args.last.is_a?(Hash) ? args.last : {}
                yielded = false
                result = self.class.state_machine(#{name.inspect}).send(:around_save, self) do
                  yielded = true
                  super
                end
                
                if yielded || result
                  result
                else
                  #{handle_save_failure}
                end
              end
            end_eval
          else
            super
          end
        end
        
        # Handles how save failures (due to invalid transitions) are raised
        def handle_save_failure
          'raise_hook_failure(:before_transition) if raise_on_failure?(opts)'
        end
        
        # Runs state events around the machine's :save action
        def around_save(object)
          result = transaction(object) do
            object.class.state_machines.transitions(object, action).perform { yield }
          end
          result
        end
        
        # Adds hooks into validation for automatically firing events
        def define_validation_hook
          define_helper :instance, <<-end_eval, __FILE__, __LINE__ + 1
            def around_validation(*)
              self.class.state_machines.transitions(self, :save, :after => false).perform { super }
            end
          end_eval
        end
        
        # Gets the db default for the machine's attribute
        def owner_class_attribute_default
          if owner_class.db.table_exists?(owner_class.table_name) && column = owner_class.db_schema[attribute.to_sym]
            column[:default]
          end
        end
        
        # Uses the DB literal to match the default against the specified state
        def owner_class_attribute_default_matches?(state)
          owner_class.db.literal(state.value) == owner_class_attribute_default
        end
        
        # Creates a scope for finding records *with* a particular state or
        # states for the attribute
        def create_with_scope(name)
          create_scope(name, lambda {|dataset, values| dataset.filter(attribute_column => values)})
        end
        
        # Creates a scope for finding records *without* a particular state or
        # states for the attribute
        def create_without_scope(name)
          create_scope(name, lambda {|dataset, values| dataset.exclude(attribute_column => values)})
        end

        # Creates a new named scope with the given name
        def create_scope(name, scope)
          machine = self
          owner_class.def_dataset_method(name) do |*states|
            machine.send(:run_scope, scope, self, states)
          end
          
          false
        end
        
        # Generates the results for the given scope based on one or more states to
        # filter by
        def run_scope(scope, dataset, states)
          super(scope, model_from_dataset(dataset).state_machine(name), dataset, states)
        end
        
        # Determines the model associated with the given dataset
        def model_from_dataset(dataset)
          dataset.model
        end
        
        # Generates the fully-qualifed column name for this machine's attribute
        def attribute_column
          ::Sequel::SQL::QualifiedIdentifier.new(owner_class.table_name, attribute)
        end
        
        # Runs a new database transaction, rolling back any changes if the
        # yielded block fails (i.e. returns false).
        def transaction(object)
          result = nil
          object.db.transaction do
            raise ::Sequel::Error::Rollback unless result = yield
          end
          result
        end
        
        # Creates a new callback in the callback chain, always ensuring that
        # it's configured to bind to the object as this is the convention for
        # Sequel callbacks
        def add_callback(type, options, &block)
          options[:bind_to_object] = true
          options[:terminator] = @terminator ||= lambda {|result| result == false}
          super
        end
    end
  end
end
