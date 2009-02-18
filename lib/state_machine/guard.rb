require 'state_machine/matcher'
require 'state_machine/eval_helpers'
require 'state_machine/assertions'

module StateMachine
  # Represents a set of requirements that must be met in order for a transition
  # or callback to occur.  Guards verify that the event, from state, and to
  # state of the transition match, in addition to if/unless conditionals for
  # an object's state.
  class Guard
    include Assertions
    include EvalHelpers
    
    # The condition that must be met on an object
    attr_reader :if_condition
    
    # The condition that must *not* be met on an object
    attr_reader :unless_condition
    
    # The requirement for verifying the event being guarded (includes :on and
    # :except_on).
    attr_reader :event_requirement
    
    # The requirement for verifying the states being guarded (includes :from,
    # :to, :except_from, and :except_to).  All options map to
    # either nil (if not specified) or an array of state names.
    attr_reader :state_requirement
    
    # A list of all of the states known to this guard.  This will pull states
    # from the following options in +state_requirements+ (in the same order):
    # * +from+ / +except_from+
    # * +to+ / +except_to+
    attr_reader :known_states
    
    # Creates a new guard
    def initialize(options = {}) #:nodoc:
      assert_valid_keys(options, :from, :to, :on, :except_from, :except_to, :except_on, :if, :unless)
      
      # Build conditionals
      assert_exclusive_keys(options, :if, :unless)
      @if_condition = options.delete(:if)
      @unless_condition = options.delete(:unless)
      
      # Build event/state requirements
      @event_requirement = build_matcher(options, :on, :except_on)
      @state_requirement = {:from => build_matcher(options, :from, :except_from), :to => build_matcher(options, :to, :except_to)}
      
      # Track known states.  The order that requirements are iterated is based
      # on the priority in which tracked states should be added.
      @known_states = []
      [:from, :to].each {|option| @known_states |= @state_requirement[option].values}
    end
    
    # Attempts to match the given object / query against the set of requirements
    # configured for this guard.  In addition to matching the event, from state,
    # and to state, this will also check whether the configured :if/:unless
    # conditions pass on the given object.
    # 
    # This will return true or false depending on whether a match is found.
    # 
    # Query options:
    # * <tt>:from</tt> - One or more states being transitioned from.  If none
    #   are specified, then this will always match.
    # * <tt>:to</tt> - One or more states being transitioned to.  If none are
    #   specified, then this will always match.
    # * <tt>:on</tt> - One or more events that fired the transition.  If none
    #   are specified, then this will always match.
    # 
    # == Examples
    # 
    #   guard = StateMachine::Guard.new(:from => [nil, :parked], :to => :idling, :on => :ignite)
    #   
    #   # Successful
    #   guard.matches?(object, :on => :ignite)                                    # => true
    #   guard.matches?(object, :from => nil)                                      # => true
    #   guard.matches?(object, :from => :parked)                                  # => true
    #   guard.matches?(object, :to => :idling)                                    # => true
    #   guard.matches?(object, :from => :parked, :to => :idling)                  # => true
    #   guard.matches?(object, :on => :ignite, :from => :parked, :to => :idling)  # => true
    #   
    #   # Unsuccessful
    #   guard.matches?(object, :on => :park)                                      # => false
    #   guard.matches?(object, :from => :idling)                                  # => false
    #   guard.matches?(object, :to => :first_gear)                                # => false
    #   guard.matches?(object, :from => :parked, :to => :first_gear)              # => false
    #   guard.matches?(object, :on => :park, :from => :parked, :to => :idling)    # => false
    def matches?(object, query = {})
      matches_query?(query) && matches_conditions?(object)
    end
    
    # Draws a representation of this guard on the given graph.  This will draw
    # an edge between every state this guard matches *from* to either the
    # configured to state or, if none specified, then a loopback to the from
    # state.
    # 
    # For example, if the following from states are configured:
    # * +idling+
    # * +first_gear+
    # * +backing_up+
    # 
    # ...and the to state is +parked+, then the following edges will be created:
    # * +idling+      -> +parked+
    # * +first_gear+  -> +parked+
    # * +backing_up+  -> +parked+
    # 
    # Each edge will be labeled with the name of the event that would cause the
    # transition.
    # 
    # The collection of edges generated on the graph will be returned.
    def draw(graph, event, valid_states)
      edges = []
      
      # From states determined based on the known valid states
      from_states = state_requirement[:from].filter(valid_states)
      
      # If a to state is not specified, then it's a loopback and each from
      # state maps back to itself
      if state_requirement[:to].values.any?
        to_state = state_requirement[:to].values.first
        loopback = false
      else
        loopback = true
      end
      
      # Generate an edge between each from and to state
      from_states.each do |from_state|
        edges << graph.add_edge(from_state.to_s, (loopback ? from_state : to_state).to_s, :label => event.to_s)
      end
      
      edges
    end
    
    protected
      # Builds a matcher strategy to use for the given options.  If neither a
      # whitelist nor a blacklist option is specified, then an AllMatcher is
      # built.
      def build_matcher(options, whitelist_option, blacklist_option)
        assert_exclusive_keys(options, whitelist_option, blacklist_option)
        
        if options.include?(whitelist_option)
          WhitelistMatcher.new(options[whitelist_option])
        elsif options.include?(blacklist_option)
          BlacklistMatcher.new(options[blacklist_option])
        else
          AllMatcher.instance
        end
      end
      
      # Verifies that all configured requirements (event and state) match the
      # given query.  If a match is return, then a hash containing the
      # event/state requirements that passed will be returned; otherwise, nil.
      def matches_query?(query)
        query ||= {}
        matches_event?(query) && matches_states?(query)
      end
      
      # Verifies that the event requirement matches the given query
      def matches_event?(query)
        matches_requirement?(query, :on, event_requirement)
      end
      
      # Verifies that the state requirements match the given query.  If a
      # matching requirement is found, then it is returned.
      def matches_states?(query)
        [:from, :to].all? {|option| matches_requirement?(query, option, state_requirement[option])}
      end
      
      # Verifies that an option in the given query matches the values required
      # for that option
      def matches_requirement?(query, option, requirement)
        !query.include?(option) || requirement.matches?(query[option], query)
      end
      
      # Verifies that the conditionals for this guard evaluate to true for the
      # given object
      def matches_conditions?(object)
        if if_condition
          evaluate_method(object, if_condition)
        elsif unless_condition
          !evaluate_method(object, unless_condition)
        else
          true
        end
      end
  end
end
