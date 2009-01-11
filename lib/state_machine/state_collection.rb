require 'state_machine/node_collection'

module StateMachine
  # Represents a collection of states in a state machine
  class StateCollection < NodeCollection
    def initialize #:nodoc:
      super(:index => [:name, :value])
    end
    
    # Gets the order in which states should be displayed based on where they
    # were first referenced.  This will order states in the following priority:
    # 
    # 1. Initial state
    # 2. Event transitions (:from, :except_from, :to, :except_to options)
    # 3. States with behaviors
    # 4. States referenced via +state+ or +other_states+
    # 5. States referenced in callbacks
    # 
    # This order will determine how the GraphViz visualizations are rendered.
    def by_priority
      if first = @nodes.first
        machine = first.machine
        order = select {|state| state.initial}.map {|state| state.name}
        
        machine.events.each {|event| order += event.known_states}
        order += select {|state| state.methods.any?}.map {|state| state.name}
        order += keys(:name) - machine.callbacks.values.flatten.map {|callback| callback.known_states}.flatten
        order += keys(:name)
        
        order.uniq!
        order.map! {|name| self[name]}
        order
      else
        []
      end
    end
  end
end
