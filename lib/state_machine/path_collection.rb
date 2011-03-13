require 'state_machine/path'

module StateMachine
  # Represents a collection of paths that are generated based on a set of
  # requirements regarding what states to start and end on
  class PathCollection < Array
    include Assertions
    
    # The object whose state machine is being walked
    attr_reader :object
    
    # The state machine these path are walking
    attr_reader :machine
    
    # The initial state to start each path from
    attr_reader :from_name
    
    # The target state for each path
    attr_reader :to_name
    
    # Creates a new collection of paths with the given requirements.
    # 
    # Configuration options:
    # * +from+ - The initial state to start from
    # * +to+ - The target end state
    # * +deep+ - Whether to enable deep searches for the target state
    def initialize(object, machine, options = {})
      options = {:deep => false, :from => machine.states.match!(object).name}.merge(options)
      assert_valid_keys(options, :from, :to, :deep)
      
      @object = object
      @machine = machine
      @from_name = machine.states.fetch(options[:from]).name
      @to_name = options[:to] && machine.states.fetch(options[:to]).name
      @deep = options[:deep]
      
      initial_paths.each {|path| walk(path)}
    end
    
    # Lists all of the states that can be reached through the paths in this
    # collection.
    # 
    # For example,
    # 
    #   paths.to_states # => [:parked, :first_gear, :second_gear, ...]
    def to_states
      map {|path| path.to_states}.flatten.uniq
    end
    
    # Lists all of the events that can be fired through the paths in this
    # collection.
    # 
    # For example,
    # 
    #   paths.events  # => [:park, :ignite, :shift_up, ...]
    def events
      map {|path| path.events}.flatten.uniq
    end
    
    private
      # Gets the initial set of paths to walk
      def initial_paths
        machine.events.transitions_for(object, :from => from_name).map do |transition|
          path = Path.new(object, machine, :target => to_name)
          path << transition
          path
        end
      end
      
      # Walks down the given path.  Each new path that matches the configured
      # requirements will be added to this collection.
      def walk(path)
        self << path if path.complete?
        path.walk {|next_path| walk(next_path)} unless to_name && path.complete? && !@deep
      end
  end
end
