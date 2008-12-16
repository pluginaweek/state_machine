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
    #     state_machine :initial => 'parked' do
    #       event :ignite do
    #         transition :to => 'idling', :from => 'parked'
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
    #   vehicle = Vehicle.create          # => #<Vehicle id: 1, name: nil, state: nil>
    #   vehicle.name = 'Ford Explorer'
    #   vehicle.ignite                    # => true
    #   vehicle.reload                    # => #<Vehicle id: 1, name: "Ford Explorer", state: "idling">
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
    #   vehicle = Vehicle.create      # => #<Vehicle id: 1, name: nil, state: nil>
    #   vehicle.ignite                # => false
    #   Message.count                 # => 0
    # 
    # *Note* that only before callbacks that halt the callback chain and
    # failed attempts to save the record will result in the transaction being
    # rolled back.  If an after callback halts the chain, the previous result
    # still applies and the transaction is *not* rolled back.
    # 
    # == Scopes
    # 
    # To assist in filtering models with specific states, a series of named
    # scopes are defined on the model for finding records with or without a
    # particular set of states.
    # 
    # These named scopes are the functional equivalent of the following
    # definitions:
    # 
    #   class Vehicle < ActiveRecord::Base
    #     named_scope :with_states, lambda {|*values| {:conditions => {:state => values.flatten}}}
    #     # with_states also aliased to with_state
    #     
    #     named_scope :without_states, lambda {|*values| {:conditions => ['state NOT IN (?)', values.flatten]}}
    #     # without_states also aliased to without_state
    #   end
    # 
    # Because of the way named scopes work in ActiveRecord, they can be
    # chained like so:
    # 
    #   Vehicle.with_state('parked').all(:order => 'id DESC')
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
    #     state_machine :initial => 'parked' do
    #       before_transition :to => 'idling' do |vehicle|
    #         vehicle.put_on_seatbelt
    #       end
    #       
    #       before_transition do |vehicle, transition|
    #         # log message
    #       end
    #       
    #       event :ignite do
    #         transition :to => 'idling', :from => 'parked'
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
    # transitions that can be hooked in.  As a result, observers can only
    # hook into before/after callbacks for events and generic transitions
    # like so:
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
      # Should this integration be used for state machines in the given class?
      # Classes that inherit from ActiveRecord::Base will automatically use
      # the ActiveRecord integration.
      def self.matches?(klass)
        defined?(::ActiveRecord::Base) && klass <= ::ActiveRecord::Base
      end
      
      # Runs a new database transaction, rolling back any changes by raising
      # an ActiveRecord::Rollback exception if the yielded block fails
      # (i.e. returns false).
      def within_transaction(object)
        object.class.transaction {raise ::ActiveRecord::Rollback unless yield}
      end
      
      protected
        # Adds the default callbacks for notifying ActiveRecord observers
        # before/after a transition has been performed.
        def after_initialize
          # Observer callbacks never halt the chain; result is ignored
          callbacks[:before] << Callback.new {|object, transition| notify(:before, object, transition)}
          callbacks[:after] << Callback.new {|object, transition, result| notify(:after, object, transition)}
        end
        
        # Sets the default action for all ActiveRecord state machines to +save+
        def default_action
          :save
        end
        
        # Forces all attribute methods to be generated for the model so that
        # the reader/writer methods for the attribute are available
        def define_attribute_accessor
          if owner_class.table_exists?
            owner_class.define_attribute_methods
            
            # Support attribute predicate for ActiveRecord columns
            if owner_class.column_names.include?(attribute)
              attribute = self.attribute
              
              owner_class.class_eval do
                define_method("#{attribute}?") do |*args|
                  if args.empty?
                    # No arguments: querying for presence of the attribute
                    super
                  else
                    # Arguments: querying for the attribute's current value
                    state = args.first
                    raise ArgumentError, "#{state.inspect} is not a known #{attribute} value" unless self.class.state_machines[attribute].states.include?(state)
                    send(attribute) == state
                  end
                end
              end
            end
          end
          
          super
        end
        
        # Defines a scope for finding records *with* a particular value or
        # values for the attribute
        def define_with_scope(name)
          attribute = self.attribute
          owner_class.named_scope name.to_sym, lambda {|*values| {:conditions => {attribute => values.flatten}}}
        end
        
        # Defines a scope for finding records *without* a particular value or
        # values for the attribute
        def define_without_scope(name)
          attribute = self.attribute
          owner_class.named_scope name.to_sym, lambda {|*values| {:conditions => ["#{attribute} NOT IN (?)", values.flatten]}}
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
        # Notifies observers on the given object that a callback occurred
        # involving the given transition.  This will attempt to call the
        # following methods on observers:
        # * #{type}_#{event}
        # * #{type}_transition
        # 
        # This will always return true regardless of the results of the
        # callbacks.
        def notify(type, object, transition)
          ["#{type}_#{transition.event}", "#{type}_transition"].each do |method|
            object.class.class_eval do
              @observer_peers.dup.each do |observer|
                observer.send(method, object, transition) if observer.respond_to?(method)
              end if defined?(@observer_peers)
            end
          end
          
          true
        end
    end
  end
end
