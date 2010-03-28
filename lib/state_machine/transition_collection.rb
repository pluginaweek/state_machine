module StateMachine
  # Represents a collection of transitions in a state machine
  class TransitionCollection < Array
    # Whether to skip running the action for each transition's machine
    attr_reader :skip_actions
    
    # Whether to skip running the after callbacks
    attr_reader :skip_after
    
    # Whether transitions should wrapped around a transaction block
    attr_reader :use_transaction
    
    # Creates a new collection of transitions that can be run in parallel.  Each
    # transitions *must* be for a different attribute.
    # 
    # Configuration options:
    # * <tt>:actions</tt> - Whether to run the action configured for each transition
    # * <tt>:after</tt> - Whether to run after callbacks
    # * <tt>:transaction</tt> - Whether to wrap transitions within a transaction
    def initialize(transitions, options = {})
      super(transitions)
      
      attributes = map {|transition| transition.attribute}.uniq
      raise ArgumentError, 'Cannot perform multiple transitions in parallel for the same state machine attribute' if attributes.length != transitions.length
      
      @skip_actions = options[:actions] == false
      @skip_after = options[:after] == false
      @use_transaction = options[:transaction] != false
      @results = {}
      @success = false
    end
    
    # Runs each of the collection's transitions in parallel.
    # 
    # All transitions will run through the following steps:
    # 1. Before callbacks
    # 2. Persist state
    # 3. Invoke action
    # 4. After callbacks (if configured)
    # 5. Rollback (if action is unsuccessful)
    # 
    # If a block is passed to this method, that block will be called instead
    # of invoking each transition's action.
    def perform(&block)
      within_transaction do
        if before
          persist
          run_actions(&block)
          after unless skip_after && success?
          rollback unless success?
        end
      end
      
      success?
    end
    
    # Runs a block within a transaction for the object being transitioned.  If
    # transactions are disabled, then this is a no-op.
    def within_transaction
      if use_transaction
        first.within_transaction do
          yield
          success?
        end
      else
        yield
      end
    end
    
    # Runs the +before+ callbacks for each transition.  If the +before+ callback
    # chain is halted for any transition, then the remaining transitions will be
    # skipped.
    def before
      all? {|transition| transition.before}
    end
    
    # Transitions the current value of the object's states to those specified by
    # each transition
    def persist
      each {|transition| transition.persist}
    end
    
    # Runs the actions for each transition.  If a block is given method, then it
    # will be called instead of invoking each transition's action.
    # 
    # The results of the actions will be used to determine #success?.
    def run_actions
      begin
        @success = if block_given?
          result = yield
          actions.each {|action| @results[action] = result}
          !!result
        else
          actions.compact.each {|action| !skip_actions && @results[action] = object.send(action)}
          @results.values.all?
        end
      rescue Exception
        rollback
        raise
      end
    end
    
    # Runs the +after+ callbacks for each transition
    def after
      each {|transition| transition.after(@results[transition.action], success?)}
    end
    
    # Rolls back changes made to the object's states via each transition
    def rollback
      each {|transition| transition.rollback}
    end
    
    # Did each transition perform successfully?  This will only be true if the
    # following requirements are met:
    # * No +before+ callbacks halt
    # * All actions run successfully (always true if skipping actions)
    def success?
      @success
    end
    
    private
      # Gets the object being transitioned
      def object
        first.object
      end
      
      # Gets the list of actions to run.  If configured to skip actions, then
      # this will return an empty collection.
      def actions
        map {|transition| transition.action}.uniq
      end
  end
end
