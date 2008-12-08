module PluginAWeek #:nodoc:
  module StateMachine
    module Integrations #:nodoc:
      # Adds support for integrating state machines with DataMapper resources.
      # 
      # == Examples
      # 
      # Below is an example of a simple state machine defined within a
      # DataMapper resource:
      # 
      #   class Vehicle
      #     include DataMapper::Resource
      #     
      #     property :id, Serial
      #     property :name, String
      #     property :state, String
      #     
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
      # is the +save+ action.  This will cause the resource to save the changes
      # made to the state machine's attribute.  *Note* that if any other changes
      # were made to the resource prior to transition, then those changes will
      # be made as well.
      # 
      # For example,
      # 
      #   vehicle = Vehicle.create          # => #<Vehicle id=1 name=nil state=nil>
      #   vehicle.name = 'Ford Explorer'
      #   vehicle.ignite                    # => true
      #   vehicle.reload                    # => #<Vehicle id=1 name="Ford Explorer" state="idling">
      # 
      # == Transactions
      # 
      # In order to ensure that any changes made during transition callbacks
      # are rolled back during a failed attempt, every transition is wrapped
      # within a transaction.
      # 
      # For example,
      # 
      #   class Message
      #     include DataMapper::Resource
      #     
      #     property :id, Serial
      #     property :content, String
      #   end
      #   
      #   Vehicle.state_machine do
      #     before_transition do |transition|
      #       Message.create(:content => transition.inspect)
      #       throw :halt
      #     end
      #   end
      #   
      #   vehicle = Vehicle.create      # => #<Vehicle id=1 name=nil state=nil>
      #   vehicle.ignite                # => false
      #   Message.all.count             # => 0
      # 
      # *Note* that only before callbacks that halt the callback chain and
      # failed attempts to save the record will result in the transaction being
      # rolled back.  If an after callback halts the chain, the previous result
      # still applies and the transaction is *not* rolled back.
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
      #   class Vehicle
      #     include DataMapper::Resource
      #     
      #     property :id, Serial
      #     property :state, String
      #     
      #     class << self
      #       def with_states(*values)
      #         all(:state => values)
      #       end
      #       alias_method :with_state, :with_states
      #       
      #       def without_states(*values)
      #         all(:state.not => values
      #       end
      #       alias_method :without_state, :without_states
      #     end
      #   end
      # 
      # Because of the way scopes work in DataMapper, they can be chained like
      # so:
      # 
      #   Vehicle.with_state('parked').with_state('idling').all(:order => [:id.desc])
      # 
      # == Callbacks / Observers
      # 
      # All before/after transition callbacks defined for DataMapper resources
      # behave in the same way that other DataMapper hooks behave.  Rather than
      # passing in the record as an argument to the callback, the callback is
      # instead bound to the object and evaluated within its context.
      # 
      # For example,
      # 
      #   class Vehicle
      #     include DataMapper::Resource
      #     
      #     property :id, Serial
      #     property :state, String
      #     
      #     state_machine :initial => 'parked' do
      #       before_transition :to => 'idling' do
      #         put_on_seatbelt
      #       end
      #       
      #       before_transition do |transition|
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
      # In addition to support for DataMapper-like hooks, there is additional
      # support for DataMapper observers.  See PluginAWeek::StateMachine::Integrations::DataMapper::Observer
      # for more information.
      module DataMapper
        # Should this integration be used for state machines in the given class?
        # Classes that include DataMapper::Resource will automatically use the
        # DataMapper integration.
        def self.matches?(klass)
          defined?(::DataMapper::Resource) && klass <= ::DataMapper::Resource
        end
        
        # Loads additional files specific to DataMapper
        def self.extended(base) #:nodoc:
          require 'state_machine/integrations/data_mapper/observer'
        end
        
        # Runs a new database transaction, rolling back any changes if the
        # yielded block fails (i.e. returns false).
        def within_transaction(object)
          object.class.transaction {|t| t.rollback if yield == false}
        end
        
        protected
          # Sets the default action for all DataMapper state machines to +save+
          def default_action
            :save
          end
          
          # Defines a scope for finding records *with* a particular value or
          # values for the attribute
          def define_with_scope(name)
            attribute = self.attribute
            (class << owner_class; self; end).class_eval do
              define_method(name) {|*values| all(attribute => values.flatten)}
            end
          end
          
          # Defines a scope for finding records *without* a particular value or
          # values for the attribute
          def define_without_scope(name)
            attribute = self.attribute
            (class << owner_class; self; end).class_eval do
              define_method(name) {|*values| all(attribute.to_sym.not => values.flatten)}
            end
          end
          
          # Creates a new callback in the callback chain, always ensuring that
          # it's configured to bind to the object as this is the convention for
          # DataMapper/Extlib callbacks
          def add_callback(type, options, &block)
            @callbacks[type] << Callback.new(options.merge(:bind_to_object => true), &block)
          end
      end
    end
  end
end
