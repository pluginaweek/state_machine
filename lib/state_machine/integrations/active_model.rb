module StateMachine
  module Integrations #:nodoc:
    # Adds support for integrating state machines with ActiveModel classes.
    # 
    # == Examples
    # 
    # If using ActiveModel directly within your class, then any one of the
    # following features need to be included in order for the integration to be
    # detected:
    # * ActiveModel::Dirty
    # * ActiveModel::Observing
    # * ActiveModel::Validations
    # 
    # Below is an example of a simple state machine defined within an
    # ActiveModel class:
    # 
    #   class Vehicle
    #     include ActiveModel::Dirty
    #     include ActiveModel::Observing
    #     include ActiveModel::Validations
    #     
    #     attr_accessor :state
    #     define_attribute_methods [:state]
    #     
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
    # By default, no action will be invoked when a state is transitioned.  This
    # means that if you want to save changes when transitioning, you must
    # define the action yourself like so:
    # 
    #   class Vehicle
    #     include ActiveModel::Validations
    #     attr_accessor :state
    #     
    #     state_machine :action => :save do
    #       ...
    #     end
    #     
    #     def save
    #       # Save changes
    #     end
    #   end
    # 
    # == Validation errors
    # 
    # In order to hook in validation support for your model, the
    # ActiveModel::Validations feature must be included.  If this is included
    # and an event fails to successfully fire because there are no matching
    # transitions for the object, a validation error is added to the object's
    # state attribute to help in determining why it failed.
    # 
    # For example,
    # 
    #   vehicle = Vehicle.new
    #   vehicle.ignite                # => false
    #   vehicle.errors.full_messages  # => ["State cannot transition via \"ignite\""]
    # 
    # == Callbacks
    # 
    # All before/after transition callbacks defined for ActiveModel models
    # behave in the same way that other ActiveSupport callbacks behave.  The
    # object involved in the transition is passed in as an argument.
    # 
    # For example,
    # 
    #   class Vehicle
    #     include ActiveModel::Validations
    #     attr_accessor :state
    #     
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
    # In order to hook in observer support for your application, the
    # ActiveModel::Observing feature must be included.  Because of the way
    # ActiveModel observers are designed, there is less flexibility around the
    # specific transitions that can be hooked in.  However, a large number of
    # hooks *are* supported.  For example, if a transition for a object's
    # +state+ attribute changes the state from +parked+ to +idling+ via the
    # +ignite+ event, the following observer methods are supported:
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
    #   class VehicleObserver < ActiveModel::Observer
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
    #   class StateMachineObserver < ActiveModel::Observer
    #     observe Vehicle, Switch, Project
    #     
    #     def after_transition(object, transition)
    #       Audit.log(object, transition)
    #     end
    #   end
    # 
    # == Dirty Attribute Tracking
    # 
    # In order to hook in validation support for your model, the
    # ActiveModel::Validations feature must be included.  If this is included
    # then state attributes will always be properly marked as changed whether
    # they were a callback or not.
    # 
    # For example,
    # 
    #   class Vehicle
    #     include ActiveModel::Dirty
    #     attr_accessor :state
    #     
    #     state_machine :initial => :parked do
    #       event :park do
    #         transition :parked => :parked
    #       end
    #     end
    #   end
    #   
    #   vehicle = Vehicle.new
    #   vehicle.changed         # => []
    #   vehicle.park            # => true
    #   vehicle.changed         # => ["state"]
    # 
    # == Creating new integrations
    # 
    # If you want to integrate state_machine with an ORM that implements parts
    # or all of the ActiveModel API, the following features must be specified:
    # * i18n scope (locale)
    # * Machine defaults
    # 
    # For example,
    # 
    #   module StateMachine::Integrations::MyORM
    #     include StateMachine::Integrations::ActiveModel
    #     
    #     @defaults = {:action = > :persist}
    #     
    #     def self.matches?(klass)
    #       defined?(::MyORM::Base) && klass <= ::MyORM::Base
    #     end
    #     
    #     def self.extended(base)
    #       locale = "#{File.dirname(__FILE__)}/my_orm/locale.rb"
    #       I18n.load_path << locale unless I18n.load_path.include?(locale)
    #     end
    #     
    #     protected
    #       def runs_validation_on_action?
    #         action == :persist
    #       end
    #       
    #       def i18n_scope
    #         :myorm
    #       end
    #   end
    # 
    # If you wish to implement other features, such as attribute initialization
    # with protected attributes, named scopes, or database transactions, you
    # must add these independent of the ActiveModel integration.  See the
    # ActiveRecord implementation for examples of these customizations.
    module ActiveModel
      module ClassMethods
        # The default options to use for state machines using this integration
        attr_reader :defaults
        
        # Loads additional files specific to ActiveModel
        def extended(base) #:nodoc:
          require 'state_machine/integrations/active_model/observer'
          
          if Object.const_defined?(:I18n)
            locale = "#{File.dirname(__FILE__)}/active_model/locale.rb"
            I18n.load_path.unshift(locale) unless I18n.load_path.include?(locale)
          end
        end
      end
      
      def self.included(base) #:nodoc:
        base.class_eval do
          extend ClassMethods
        end
      end
      
      extend ClassMethods
      
      # Should this integration be used for state machines in the given class?
      # Classes that include ActiveModel::Dirty, ActiveModel::Observing, or
      # ActiveModel::Validations will automatically use the ActiveModel
      # integration.
      def self.matches?(klass)
        features = %w(Dirty Observing Validations)
        defined?(::ActiveModel) && features.any? {|feature| ::ActiveModel.const_defined?(feature) && klass <= ::ActiveModel.const_get(feature)}
      end
      
      @defaults = {}
      
      # Forces the change in state to be recognized regardless of whether the
      # state value actually changed
      def write(object, attribute, value)
        result = super
        if attribute == :state && supports_dirty_tracking?(object) && !object.send("#{self.attribute}_changed?")
          object.send("#{self.attribute}_will_change!")
        end
        result
      end
      
      # Adds a validation error to the given object 
      def invalidate(object, attribute, message, values = [])
        if supports_validations?
          attribute = self.attribute(attribute)
          ancestors = ancestors_for(object.class)
          
          options = values.inject({}) do |options, (key, value)|
            # Generate all possible translation keys
            group = key.to_s.pluralize
            translations = ancestors.map {|ancestor| :"#{ancestor.model_name.underscore}.#{name}.#{group}.#{value}"}
            translations.concat([:"#{name}.#{group}.#{value}", :"#{group}.#{value}", value.to_s])
            
            options[key] = I18n.translate(translations.shift, :default => translations, :scope => [i18n_scope, :state_machines])
            options
          end
          
          object.errors.add(attribute, message, options.merge(:default => @messages[message]))
        end
      end
      
      # Resets any errors previously added when invalidating the given object
      def reset(object)
        object.errors.clear if supports_validations?
      end
      
      protected
        # Whether observers are supported in the integration.  Only true if
        # ActiveModel::Observer is available.
        def supports_observers?
          defined?(::ActiveModel::Observing) && owner_class <= ::ActiveModel::Observing
        end
        
        # Whether validations are supported in the integration.  Only true if
        # the ActiveModel feature is enabled on the owner class.
        def supports_validations?
          defined?(::ActiveModel::Validations) && owner_class <= ::ActiveModel::Validations
        end
        
        # Do validations run when the action configured this machine is
        # invoked?  This is used to determine whether to fire off attribute-based
        # event transitions when the action is run.
        def runs_validations_on_action?
          false
        end
        
        # Whether change (dirty) tracking is supported in the integration.
        # Only true if the ActiveModel feature is enabled on the owner class.
        def supports_dirty_tracking?(object)
          defined?(::ActiveModel::Dirty) && owner_class <= ::ActiveModel::Dirty && object.respond_to?("#{self.attribute}_changed?")
        end
        
        # Determines the base scope to use when looking up translations
        def i18n_scope
          owner_class.i18n_scope
        end
        
        # Build a list of ancestors for the given class to use when
        # determining which localization key to use for a particular string.
        def ancestors_for(klass)
          klass.lookup_ancestors
        end
        
        # Gets the terminator to use for callbacks
        def callback_terminator
          @terminator ||= lambda {|result| result == false}
        end
        
        # Adds the default callbacks for notifying ActiveModel observers
        # before/after a transition has been performed.
        def after_initialize
          if supports_observers?
            callbacks[:before] << Callback.new(:before) {|object, transition| notify(:before, object, transition)}
            callbacks[:after] << Callback.new(:after) {|object, transition| notify(:after, object, transition)}
          end
        end
        
        # Skips defining reader/writer methods since this is done automatically
        def define_state_accessor
          name = self.name
          
          owner_class.validates_each(attribute) do |object, attr, value|
            machine = object.class.state_machine(name)
            machine.invalidate(object, :state, :invalid) unless machine.states.match(object)
          end if supports_validations?
        end
        
        # Adds hooks into validation for automatically firing events
        def define_action_helpers(*args)
          super
          
          action = self.action
          @instance_helper_module.class_eval do
            define_method(:valid?) do |*args|
              self.class.state_machines.transitions(self, action, :after => false).perform { super(*args) }
            end
          end if runs_validations_on_action?
        end
        
        # Creates a new callback in the callback chain, always inserting it
        # before the default Observer callbacks that were created after
        # initialization.
        def add_callback(type, options, &block)
          options[:terminator] = callback_terminator
          
          if supports_observers?
            @callbacks[type == :around ? :before : type].insert(-2, callback = Callback.new(type, options, &block))
            add_states(callback.known_states)
            callback
          else
            super
          end
        end
        
      private
        # Notifies observers on the given object that a callback occurred
        # involving the given transition.  This will attempt to call the
        # following methods on observers:
        # * #{type}_#{qualified_event}_from_#{from}_to_#{to}
        # * #{type}_#{qualified_event}_from_#{from}
        # * #{type}_#{qualified_event}_to_#{to}
        # * #{type}_#{qualified_event}
        # * #{type}_transition_#{machine_name}_from_#{from}_to_#{to}
        # * #{type}_transition_#{machine_name}_from_#{from}
        # * #{type}_transition_#{machine_name}_to_#{to}
        # * #{type}_transition_#{machine_name}
        # * #{type}_transition
        # 
        # This will always return true regardless of the results of the
        # callbacks.
        def notify(type, object, transition)
          name = self.name
          event = transition.qualified_event
          from = transition.from_name
          to = transition.to_name
          
          # Machine-specific updates
          ["#{type}_#{event}", "#{type}_transition_#{name}"].each do |event_segment|
            ["_from_#{from}", nil].each do |from_segment|
              ["_to_#{to}", nil].each do |to_segment|
                object.class.changed if object.class.respond_to?(:changed)
                object.class.notify_observers([event_segment, from_segment, to_segment].join, object, transition)
              end
            end
          end
          
          # Generic updates
          object.class.changed if object.class.respond_to?(:changed)
          object.class.notify_observers("#{type}_transition", object, transition)
          
          true
        end
    end
  end
end
