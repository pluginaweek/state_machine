require 'state_machine/eval_helpers'
require 'state_machine/assertions'

module PluginAWeek #:nodoc:
  module StateMachine
    # Represents a set of requirements that must be met in order for a transition
    # or callback to occur.  Guards verify that the event, from state, and to
    # state of the transition match, in addition to if/unless conditionals for
    # an object's state.
    class Guard
      include Assertions
      include EvalHelpers
      
      # The transition/conditional options that must be met in order for the
      # guard to match
      attr_reader :requirements
      
      # A list of all of the states known to this guard.  This will pull state
      # names from the following requirements:
      # * +to+
      # * +from+
      # * +except_to+
      # * +except_from+
      attr_reader :known_states
      
      # Creates a new guard with the given requirements
      def initialize(requirements = {}) #:nodoc:
        assert_valid_keys(requirements, :to, :from, :on, :except_to, :except_from, :except_on, :if, :unless)
        
        @requirements = requirements
        @known_states = [:to, :from, :except_to, :except_from].inject([]) {|states, option| states |= Array(requirements[option])}
      end
      
      # Determines whether the given object / query matches the requirements
      # configured for this guard.  In addition to matching the event, from state,
      # and to state, this will also check whether the configured :if/:unless
      # conditionals pass on the given object.
      # 
      # Query options:
      # * +to+ - One or more states being transitioned to.  If none are specified, then this will always match.
      # * +from+ - One or more states being transitioned from.  If none are specified, then this will always match.
      # * +on+ - One or more events that fired the transition.  If none are specified, then this will always match.
      # * +except_to+ - One more states *not* being transitioned to
      # * +except_from+ - One or more states *not* being transitioned from
      # * +except_on+ - One or more events that *did not* fire the transition.
      # 
      # == Examples
      # 
      #   guard = PluginAWeek::StateMachine::Guard.new(:on => 'ignite', :from => 'parked', :to => 'idling')
      #   
      #   # Successful
      #   guard.matches?(object, :on => 'ignite')                                      # => true
      #   guard.matches?(object, :from => 'parked')                                    # => true
      #   guard.matches?(object, :to => 'idling')                                      # => true
      #   guard.matches?(object, :from => 'parked', :to => 'idling')                   # => true
      #   guard.matches?(object, :on => 'ignite', :from => 'parked', :to => 'idling')  # => true
      #   
      #   # Unsuccessful
      #   guard.matches?(object, :on => 'park')                                        # => false
      #   guard.matches?(object, :from => 'idling')                                    # => false
      #   guard.matches?(object, :to => 'first_gear')                                  # => false
      #   guard.matches?(object, :from => 'parked', :to => 'first_gear')               # => false
      #   guard.matches?(object, :on => 'park', :from => 'parked', :to => 'idling')    # => false
      def matches?(object, query = {})
        matches_query?(object, query) && matches_conditions?(object)
      end
      
      protected
        # Verify that the from state, to state, and event match the query
        def matches_query?(object, query)
          (!query || query.empty?) ||
          find_match(query[:from], requirements[:from], requirements[:except_from]) &&
          find_match(query[:to], requirements[:to], requirements[:except_to]) &&
          find_match(query[:on], requirements[:on], requirements[:except_on])
        end
        
        # Verify that the conditionals for this guard evaluate to true for the
        # given object
        def matches_conditions?(object)
          if requirements[:if]
            evaluate_method(object, requirements[:if])
          elsif requirements[:unless]
            !evaluate_method(object, requirements[:unless])
          else
            true
          end
        end
        
        # Attempts to find the given value in either a whitelist of values or
        # a blacklist of values.  The whitelist will always be used first if it
        # is specified.  If neither lists are specified or the value is blank,
        # then this will always find a match and return true.
        # 
        # == Examples
        # 
        #   find_match(nil, %w(parked idling), nil)             # => true
        #   find_match('parked', nil, nil)                      # => true
        #   find_match('parked', %w(parked idling), nil)        # => true
        #   find_match('first_gear', %w(parked idling, nil)     # => false
        #   find_match('parked', nil, %w(parked idling))        # => false
        #   find_match('first_gear', nil, %w(parked idling))    # => true
        def find_match(value, whitelist, blacklist)
          if value
            if whitelist
              Array(whitelist).include?(value)
            elsif blacklist
              !Array(blacklist).include?(value)
            else
              true
            end
          else
            true
          end
        end
    end
  end
end
