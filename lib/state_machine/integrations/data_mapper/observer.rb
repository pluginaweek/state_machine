module PluginAWeek #:nodoc:
  module StateMachine
    module Integrations #:nodoc:
      module DataMapper
        # Adds support for creating before/after transition callbacks within a
        # DataMapper observer.  These callbacks behave very similarly to
        # before/after hooks during save/update/destroy/etc., but with the
        # following modifications:
        # * Each callback can define a set of transition conditions (i.e. guards)
        # that must be met in order for the callback to get invoked.
        # * An additional transition parameter is available that provides
        # contextual information about the event (see PluginAWeek::StateMachine::Transition
        # for more information)
        # 
        # To define a single observer for multiple state machines:
        # 
        #   class StateMachineObserver
        #     include DataMapper::Observer
        #     
        #     observe Vehicle, Switch, Project
        #     
        #     after_transition do |transition, saved|
        #       Audit.log(self, transition) if saved
        #     end
        #   end
        module Observer
          # Creates a callback that will be invoked *before* a transition is
          # performed, so long as the given configuration options match the
          # transition.  Each part of the transition (event, to state, from state)
          # must match in order for the callback to get invoked.
          # 
          # See PluginAWeek::StateMachine::Machine#before_transition for more
          # information about the various configuration options available.
          # 
          # == Examples
          # 
          #   class Vehicle
          #     include DataMapper::Resource
          #     
          #     property :id, Serial
          #     property :state, :String
          #     
          #     state_machine :initial => 'parked' do
          #       event :ignite do
          #         transition :to => 'idling', :from => 'parked'
          #       end
          #     end
          #   end
          #   
          #   class VehicleObserver
          #     include DataMapper::Observer
          #     
          #     observe Vehicle
          #     
          #     before :save do
          #       # log message
          #     end
          #     
          #     before_transition :to => 'idling', :from => 'parked', :on => 'ignite' do
          #       # put on seatbelt
          #     end
          #     
          #     before_transition do |transition|
          #       # log message
          #     end
          #   end
          # 
          # *Note* that in each of the above +before_transition+ callbacks, the
          # callback is executed within the context of the object (i.e. the
          # Vehicle instance being transition).  This means that +self+ refers
          # to the vehicle record within each callback block.
          def before_transition(*args, &block)
            add_transition_callback(:before, *args, &block)
          end
          
          # Creates a callback that will be invoked *after* a transition is
          # performed, so long as the given configuration options match the
          # transition.  Each part of the transition (event, to state, from state)
          # must match in order for the callback to get invoked.
          # 
          # See PluginAWeek::StateMachine::Machine#after_transition for more
          # information about the various configuration options available.
          # 
          # == Examples
          # 
          #   class Vehicle
          #     include DataMapper::Resource
          #     
          #     property :id, Serial
          #     property :state, :String
          #     
          #     state_machine :initial => 'parked' do
          #       event :ignite do
          #         transition :to => 'idling', :from => 'parked'
          #       end
          #     end
          #   end
          #   
          #   class VehicleObserver
          #     include DataMapper::Observer
          #     
          #     observe Vehicle
          #     
          #     after :save do |saved|
          #       # log message
          #     end
          #     
          #     after_transition :to => 'idling', :from => 'parked', :on => 'ignite' do
          #       # put on seatbelt
          #     end
          #     
          #     after_transition do |transition, saved|
          #       if saved
          #         # log message
          #       end
          #     end
          #   end
          # 
          # *Note* that in each of the above +before_transition+ callbacks, the
          # callback is executed within the context of the object (i.e. the
          # Vehicle instance being transition).  This means that +self+ refers
          # to the vehicle record within each callback block.
          def after_transition(*args, &block)
            add_transition_callback(:after, *args, &block)
          end
          
          private
            # Adds the transition callback to a specific machine or all of the
            # state machines for each observed class.
            def add_transition_callback(type, *args, &block)
              if args.first && !args.first.is_a?(Hash)
                # Specific attribute is being targeted
                attribute = args.first.to_s
                transition_args = args[1..-1]
              else
                # Target all state machines
                attribute = nil
                transition_args = args
              end
              
              # Add the transition callback to each class being observed
              observing.each do |klass|
                state_machines = attribute ? [klass.state_machines[attribute]] : klass.state_machines.values
                state_machines.each {|machine| machine.send("#{type}_transition", *transition_args, &block)}
              end if observing
            end
        end
      end
    end
  end
end

DataMapper::Observer::ClassMethods.class_eval do
  include PluginAWeek::StateMachine::Integrations::DataMapper::Observer
end
