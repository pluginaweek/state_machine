module PluginAWeek #:nodoc:
  module Has #:nodoc:
    module States #:nodoc:
      # An active event is one which has transitions to active states in the
      # system
      module ActiveEvent
        def self.extended(event) #:nodoc:
          event.instance_eval do
            @callbacks = []
            @transitions = []
          end
          
          class << event
            attr_accessor :callbacks
            attr_reader :transitions
          end
        end
        
        # Gets the owner of this event as an actual class
        def owner_class
          owner_type.constantize
        end
        
        # Gets all of the possible transitions for the record
        def possible_transitions_from(state)
          transitions.select {|transition| transition.from_state == state}
        end
        
        # Attempts to transition to one of the next possible states.  If it is
        # successful, then any parallel machines that have been configured
        # will have their events fired as well
        def fire(record, *args)
          success = false
          
          # Find a state that we can transition into
          possible_transitions_from(record.state).each do |transition|
            if success = transition.perform(record, *args)
              record.send(:record_state_change, self, transition.from_state, transition.to_state)
              break
            end
          end
          
          success && invoke_callbacks(record, args)
        end
        
        # Creates a new transition to the specified state.
        # 
        # Configuration options:
        # <tt>from</tt> - A state or array of states that can be transitioned to
        # <tt>if</tt> - An optional condition that must be met for the transition to occur
        def transition_to(to_name, options = {})
          to_state = owner_class.active_states[to_name.to_sym]
          raise StateNotActive, "Couldn't find active #{owner_type} state with name=#{to_name.inspect}" unless to_state
          
          options.symbolize_keys!.reverse_merge!(
            :from => owner_class.active_states.keys
          )
          
          Array(options.delete(:from)).each do |from_name|
            from_state = owner_class.active_states[from_name.to_sym]
            raise StateNotActive, "Couldn't find active #{owner_type} state with name=#{from_name.inspect}" unless from_state
            
            @transitions << StateTransition.new(from_state, to_state, options)
          end
        end
        
        # Copies the content of the event, duplicating the transitions as well
        def initialize_copy(event)
          super
          
          @callbacks = event.callbacks.dup
          @transitions = event.transitions.dup
          self
        end
        
        def dup #:nodoc:
          event = super
          event.extend PluginAWeek::Has::States::ActiveEvent
          event
        end
        
        private
        def invoke_callbacks(record, args) #:nodoc:
          success = @callbacks.all? {|callback| record.eval_call(callback, *args)}
          success && (!record.respond_to?("after_#{name}") || record.send("after_#{name}"))
        end
      end
    end
  end
end