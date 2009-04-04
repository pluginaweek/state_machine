require 'state_machine/assertions'

module StateMachine
  # Represents a collection of nodes in a state machine, be it events or states.
  class NodeCollection
    include Enumerable
    include Assertions
    
    # The machine associated with the nodes
    attr_reader :machine
    
    # Creates a new collection of nodes for the given state machine.  By default,
    # the collection is empty.
    # 
    # Configuration options:
    # * <tt>:index</tt> - One or more attributes to automatically generate
    #   hashed indices for in order to perform quick lookups.  Default is to
    #   index by the :name attribute
    def initialize(machine, options = {})
      assert_valid_keys(options, :index)
      options = {:index => :name}.merge(options)
      
      @machine = machine
      @nodes = []
      @indices = Array(options[:index]).inject({}) {|indices, attribute| indices[attribute] = {}; indices}
      @default_index = Array(options[:index]).first
    end
    
    # Creates a copy of this collection such that modifications don't affect
    # the original collection
    def initialize_copy(orig) #:nodoc:
      super
      
      nodes = @nodes
      @nodes = []
      @indices = @indices.inject({}) {|indices, (name, index)| indices[name] = {}; indices}
      nodes.each {|node| self << node.dup}
    end
    
    # Changes the current machine associated with the collection.  In turn, this
    # will change the state machine associated with each node in the collection.
    def machine=(new_machine)
      @machine = new_machine
      each {|node| node.machine = new_machine}
    end
    
    # Gets the number of nodes in this collection
    def length
      @nodes.length
    end
    
    # Gets the set of unique keys for the given index
    def keys(index_name = @default_index)
      index(index_name).keys
    end
    
    # Adds a new node to the collection.  By doing so, this will also add it to
    # the configured indices.
    def <<(node)
      @nodes << node
      @indices.each {|attribute, index| index[node.send(attribute)] = node}
      self
    end
    
    # Updates the indexed keys for the given node.  If the node's attribute
    # has changed since it was added to the collection, the old indexed keys
    # will be replaced with the updated ones.
    def update(node)
      @indices.each do |attribute, index|
        old_key = RUBY_VERSION < '1.9' ? index.index(node) : index.key(node)
        new_key = node.send(attribute)
        
        # Only replace the key if it's changed
        if old_key != new_key
          index.delete(old_key)
          index[new_key] = node
        end
      end
    end
    
    # Calls the block once for each element in self, passing that element as a
    # parameter.
    # 
    #   states = StateMachine::NodeCollection.new
    #   states << StateMachine::State.new(machine, :parked)
    #   states << StateMachine::State.new(machine, :idling)
    #   states.each {|state| puts state.name, ' -- '}
    # 
    # ...produces:
    # 
    #   parked -- idling --
    def each
      @nodes.each {|node| yield node}
      self
    end
    
    # Gets the node at the given index.
    # 
    #   states = StateMachine::NodeCollection.new
    #   states << StateMachine::State.new(machine, :parked)
    #   states << StateMachine::State.new(machine, :idling)
    #   
    #   states.at(0).name    # => :parked
    #   states.at(1).name    # => :idling
    def at(index)
      @nodes[index]
    end
    
    # Gets the node indexed by the given key.  By default, this will look up the
    # key in the first index configured for the collection.  A custom index can
    # be specified like so:
    # 
    #   collection['parked', :value]
    # 
    # The above will look up the "parked" key in a hash indexed by each node's
    # +value+ attribute.
    # 
    # If the key cannot be found, then nil will be returned.
    def [](key, index_name = @default_index)
      index(index_name)[key]
    end
    
    # Gets the node indexed by the given key.  By default, this will look up the
    # key in the first index configured for the collection.  A custom index can
    # be specified like so:
    # 
    #   collection['parked', :value]
    # 
    # The above will look up the "parked" key in a hash indexed by each node's
    # +value+ attribute.
    # 
    # If the key cannot be found, then an IndexError exception will be raised:
    # 
    #   collection['invalid', :value]   # => IndexError: "invalid" is an invalid value
    def fetch(key, index_name = @default_index)
      self[key, index_name] || raise(IndexError, "#{key.inspect} is an invalid #{index_name}")
    end
    
    private
      # Gets the given index.  If the index does not exist, then an ArgumentError
      # is raised.
      def index(name)
        raise ArgumentError, 'No indices configured' unless @indices.any?
        @indices[name] || raise(ArgumentError, "Invalid index: #{name.inspect}")
      end
  end
end
