module PluginAWeek #:nodoc:
  module Has #:nodoc:
    module States #:nodoc:
      # An active event is one which has transitions to active states in the
      # system
      class ActiveEvent
        # The callbacks to invoke when the event is performed
        attr_accessor :callbacks
        
        # The possible transitions that can occur through this event
        attr_reader :transitions
        
        # The class which this is an event for
        attr_accessor :owner_class
        
        # The event which is being represented
        attr_reader :record
        
        delegate :id, :to => '@record'
        
        def initialize(owner_class, record, options = {}) #:nodoc:
          options.assert_valid_keys(:after)
          
          @owner_class, @record, @options = owner_class, record, options
          @callbacks = []
          @transitions = []
          
          add_callbacks
          add_transition_action
        end
        
        def respond_to?(symbol, include_priv = false) #:nodoc:
          super || @record.respond_to?(symbol, include_priv)
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
        
        def hash #:nodoc:
          @record.hash
        end
        
        def ==(obj) #:nodoc:
          @record == (obj.is_a?(Event) ? obj : obj.record)
        end
        alias :eql? :==
        
        private
        def method_missing(method, *args, &block) #:nodoc:
          @record.send(method, *args, &block) if @record
        end
        
        # Copies the content of the event, duplicating the transitions as well
        def initialize_copy(event)
          super
          
          @callbacks = event.callbacks.dup
          @transitions = event.transitions.dup
          self
        end
        
        # Adds the callbacks for when the event is performed
        def add_callbacks
          @callbacks << @options[:after] if @options[:after]
        end
        
        # Add action for transitioning the model
        def add_transition_action
          @owner_class.class_eval <<-end_eval
            def #{name}!(*args)
              success = false
              transaction do
                save! if new_record?
                
                if self.class.active_events[:#{name.to_s.dump}].fire(self, *args)
                  success = save!
                else
                  raise ActiveRecord::Rollback
                end
              end
              
              success
            end
            
            # Add callbacks
            def self.after_#{name}(*callbacks, &block)
              callbacks << block if block_given?
              active_events[:#{name}].callbacks.concat(callbacks)
            end
          end_eval
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