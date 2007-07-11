module PluginAWeek #:nodoc:
  module Has #:nodoc:
    module States #:nodoc:
      # An event is a description of activity that is to be performed at a
      # given moment.
      class Event
        attr_writer   :klass
        attr_reader   :record
        attr_accessor :transitions
        
        delegate      :name,
                      :id,
                        :to => :record
        delegate      :valid_state_names,
                        :to => '@klass'
        
        private       :transitions,
                      :transitions=,
                      :valid_state_names
        
        def initialize(record, options, klass, &block) #:nodoc:
          options.symbolize_keys!.assert_valid_keys(
            :parallel
          )
          
          @record, @options, @klass = record, options, klass
          @transitions = []
          
          instance_eval(&block) if block_given?
        end
        
        # Gets all of the possible next states for the record
        def next_states_for(record)
          @transitions.select {|transition| transition.from_name == record.state_name}
        end
        
        # Attempts to transition to one of the next possible states.  If it is
        # successful, then any parallel machines that have been configured
        # will have their events fired as well
        def fire(record, *args)
          success = false
          
          # Find a state that we can transition into
          original_state_name = record.state_name
          next_states_for(record).each do |transition|
            if success = transition.perform(record, *args)
              record.send(:record_transition, name, original_state_name, record.state_name)
              break
            end
          end
          
          # Execute the event on all other state machines running in parallel
          if success && parallel_state_machines = @options[:parallel]
            @parallel_state_machines ||= [parallel_state_machines].flatten.inject({}) do |machine_events, machine|
              if machine.is_a?(Hash)
                machine_events.merge!(machine)
              else
                machine_events[machine] = name
              end
              machine_events
            end
            
            @parallel_state_machines.each do |machine, event|
              machine = Symbol === machine ? record.send(machine) : machine.call(self)
              success = machine.send("#{event}!", *args)
              
              break if !success
            end
          end
          
          success
        end
        
        # Creates a new transition to the specified state.
        # 
        # Configuration options:
        # <tt>from</tt> - A state or array of states that can be transitioned to
        # <tt>if</tt> - An optional condition that must be met for the transition to occur
        def transition_to(to_name, options = {})
          raise InvalidState, "#{to_name} is not a valid state for #{self.name}" unless valid_state_names.include?(to_name.to_sym)
          
          options.symbolize_keys!
          
          Array(options.delete(:from)).each do |from_name|
            raise InvalidState, "#{from_name} is not a valid state for #{self.name}" unless valid_state_names.include?(from_name.to_sym)
            
            @transitions << PluginAWeek::Has::States::StateTransition.new(from_name, to_name, options)
          end
        end
        
        # Copies the content of the event, duplicating the transitions as well
        def dup
          event = super
          event.send(:transitions=, event.send(:transitions).dup)
          event
        end
      end
    end
  end
end