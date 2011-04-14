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
    # === Security implications
    # 
    # Beware that public event attributes mean that events can be fired
    # whenever mass-assignment is being used.  If you want to prevent malicious
    # users from tampering with events through URLs / forms, the attribute
    # should be protected like so:
    # 
    #   class Vehicle
    #     include ActiveModel::MassAssignmentSecurity
    #     attr_accessor :state
    #     
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
    #   class Vehicle
    #     include ActiveModel::MassAssignmentSecurity
    #     attr_accessor :state
    #     
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
    # * before/after/after_failure_to-_ignite_from_parked_to_idling
    # * before/after/after_failure_to-_ignite_from_parked
    # * before/after/after_failure_to-_ignite_to_idling
    # * before/after/after_failure_to-_ignite
    # * before/after/after_failure_to-_transition_state_from_parked_to_idling
    # * before/after/after_failure_to-_transition_state_from_parked
    # * before/after/after_failure_to-_transition_state_to_idling
    # * before/after/after_failure_to-_transition_state
    # * before/after/after_failure_to-_transition
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
    #     
    #     def after_failure_to_transition(vehicle, transition)
    #       Audit.error(vehicle, transition)
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
    #       def runs_validations_on_action?
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
      def self.included(base) #:nodoc:
        base.versions.unshift(*versions)
      end
      
      include Base
      extend ClassMethods
      
      require 'state_machine/integrations/active_model/versions'
      
      @defaults = {}
      
      # Whether this integration is available.  Only true if ActiveModel is
      # defined.
      def self.available?
        defined?(::ActiveModel)
      end
      
      # Should this integration be used for state machines in the given class?
      # Classes that include ActiveModel::Dirty,  ActiveModel::Observing, or
      # ActiveModel::Validations will automatically use the ActiveModel
      # integration.
      def self.matches?(klass)
        %w(Dirty Observing Validations).any? {|feature| ::ActiveModel.const_defined?(feature) && klass <= ::ActiveModel.const_get(feature)}
      end
      
      # Forces the change in state to be recognized regardless of whether the
      # state value actually changed
      def write(object, attribute, value, *args)
        result = super
        
        if (attribute == :state || attribute == :event && value) && supports_dirty_tracking?(object) && !object.send("#{self.attribute}_changed?")
          object.send("#{self.attribute}_will_change!")
        end
        
        result
      end
      
      # Adds a validation error to the given object 
      def invalidate(object, attribute, message, values = [])
        if supports_validations?
          attribute = self.attribute(attribute)
          options = values.inject({}) do |options, (key, value)|
            options[key] = value
            options
          end
          
          default_options = default_error_message_options(object, attribute, message)
          object.errors.add(attribute, message, options.merge(default_options))
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
        
        # Gets the terminator to use for callbacks
        def callback_terminator
          @terminator ||= lambda {|result| result == false}
        end
        
        # Determines the base scope to use when looking up translations
        def i18n_scope(klass)
          klass.i18n_scope
        end
        
        # The default options to use when generating messages for validation
        # errors
        def default_error_message_options(object, attribute, message)
          {:message => @messages[message]}
        end
        
        # Translates the given key / value combo.  Translation keys are looked
        # up in the following order:
        # * <tt>#{i18n_scope}.state_machines.#{model_name}.#{machine_name}.#{plural_key}.#{value}</tt>
        # * <tt>#{i18n_scope}.state_machines.#{machine_name}.#{plural_key}.#{value}</tt>
        # * <tt>#{i18n_scope}.state_machines.#{plural_key}.#{value}</tt>
        # 
        # If no keys are found, then the humanized value will be the fallback.
        def translate(klass, key, value)
          ancestors = ancestors_for(klass)
          group = key.to_s.pluralize
          value = value ? value.to_s : 'nil'
          
          # Generate all possible translation keys
          translations = ancestors.map {|ancestor| :"#{ancestor.model_name.underscore}.#{name}.#{group}.#{value}"}
          translations.concat([:"#{name}.#{group}.#{value}", :"#{group}.#{value}", value.humanize.downcase])
          I18n.translate(translations.shift, :default => translations, :scope => [i18n_scope(klass), :state_machines])
        end
        
        # Build a list of ancestors for the given class to use when
        # determining which localization key to use for a particular string.
        def ancestors_for(klass)
          klass.lookup_ancestors
        end
        
        # Initializes class-level extensions and defaults for this machine
        def after_initialize
          load_locale
          load_observer_extensions
          add_default_callbacks
        end
        
        # Loads any locale files needed for translating validation errors
        def load_locale
          I18n.load_path.unshift(@integration.locale_path) unless I18n.load_path.include?(@integration.locale_path)
        end
        
        # Loads extensions to ActiveModel's Observers
        def load_observer_extensions
          require 'state_machine/integrations/active_model/observer'
        end
        
        # Adds a set of default callbacks that utilize the Observer extensions
        def add_default_callbacks
          if supports_observers?
            callbacks[:before] << Callback.new(:before) {|object, transition| notify(:before, object, transition)}
            callbacks[:after] << Callback.new(:after) {|object, transition| notify(:after, object, transition)}
            callbacks[:failure] << Callback.new(:failure) {|object, transition| notify(:after_failure_to, object, transition)}
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
        def define_action_helpers
          super
          define_validation_hook if runs_validations_on_action?
        end
        
        # Hooks into validations by defining around callbacks for the
        # :validation event
        def define_validation_hook
          owner_class.set_callback(:validation, :around, self, :prepend => true)
        end
        
        # Runs state events around the object's validation process
        def around_validation(object)
          object.class.state_machines.transitions(object, action, :after => false).perform { yield }
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
        
        # Configures new states with the built-in humanize scheme
        def add_states(new_states)
          super.each do |state|
            state.human_name = lambda {|state, klass| translate(klass, :state, state.name)}
          end
        end
        
        # Configures new event with the built-in humanize scheme
        def add_events(new_events)
          super.each do |event|
            event.human_name = lambda {|event, klass| translate(klass, :event, event.name)}
          end
        end
        
        # Notifies observers on the given object that a callback occurred
        # involving the given transition.  This will attempt to call the
        # following methods on observers:
        # * <tt>#{type}_#{qualified_event}_from_#{from}_to_#{to}</tt>
        # * <tt>#{type}_#{qualified_event}_from_#{from}</tt>
        # * <tt>#{type}_#{qualified_event}_to_#{to}</tt>
        # * <tt>#{type}_#{qualified_event}</tt>
        # * <tt>#{type}_transition_#{machine_name}_from_#{from}_to_#{to}</tt>
        # * <tt>#{type}_transition_#{machine_name}_from_#{from}</tt>
        # * <tt>#{type}_transition_#{machine_name}_to_#{to}</tt>
        # * <tt>#{type}_transition_#{machine_name}</tt>
        # * <tt>#{type}_transition</tt>
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
