module StateMachine
  module YARD
    module Handlers
      # Handles and processes #state_machine
      class Macro < Base
        handles method_call(:state_machine)
        namespace_only
        
        def process
          # Extract configuration
          parameters = statement.parameters(false)
          name = extract_name(parameters.first)
          options = {:attribute => name}.merge(extract_options(parameters.last))
          
          # Track the state machine
          state_machine = {
            :type => :state_machine,
            :name => name,
            :namespace => namespace,
            :options => options,
            :events => [],
            :states => [],
            :transitions => [],
            :description => statement.docstring
          }
          namespace['state_machines'] ||= {}
          namespace['state_machines'][name] = state_machine
          
          # Merge superclass definitions
          each_ancestor_machine(name) do |ancestor_machine|
            state_machine[:options].merge!(ancestor_machine[:options])
            state_machine[:transitions].concat(ancestor_machine[:transitions])
            [:attribute, :namespace, :description].each do |key|
              state_machine[key] ||= ancestor_machine[key]
            end
          end
          
          # Parse the block
          parse_block(statement.last.last, :owner => state_machine)
          
          # Remove duplicates
          state_machine[:states].uniq!
          state_machine[:events].uniq!
          
          # Remove states / events that have already been defined in an ancestor
          each_ancestor_machine(name) do |ancestor_machine|
            state_machine[:states] -= ancestor_machine[:states]
            state_machine[:events] -= ancestor_machine[:events]
          end
          
          # Define auto-generated methods
          define_macro_methods(state_machine) unless inherited?(name)
          define_state_methods(state_machine)
          define_event_methods(state_machine)
        end
        
        private
          # Extracts the state machine name from the given node
          def extract_name(ast)
            if ast && [:symbol_literal, :string_literal].include?(ast.type)
              extract_node_name(ast)
            else
              :state
            end
          end
          
          # Extracts the state machine options from the given node
          def extract_options(ast)
            options = {}
            
            if ast && ![:symbol_literal, :string_literal].include?(ast.type)
              ast.children.each do |assoc|
                key = extract_node_name(assoc[0])
                value = [:symbol_literal, :string_literal].include?(assoc[1].type) ? extract_node_name(assoc[1]) : assoc[1].source
                options[key] = value
              end
            end
            
            options
          end
          
          # Is this state machine inherited from an ancestor?
          def inherited?(name)
            inherited = false
            each_ancestor_machine(name) { inherited = true }
            inherited
          end
          
          # Iterates over each ancestor that has a state machine with the given
          # name.  This ensures each ancestor has been loaded prior to looking
          # up their definitions.
          def each_ancestor_machine(name)
            namespace.inheritance_tree.each do |ancestor|
              begin
                ensure_loaded!(ancestor)
              rescue ::YARD::Handlers::NamespaceMissingError
                # Ignore: just means that we can't access an ancestor
              end
            end
            
            namespace.inheritance_tree.reverse.each do |ancestor|
              parsed = ancestor != namespace && ancestor.is_a?(::YARD::CodeObjects::ClassObject)
              if parsed && ancestor['state_machines'] && ancestor_machine = ancestor['state_machines'][name]
                yield ancestor_machine
              end
            end
          end
          
          # Defines auto-generated macro methods for the given machine
          def define_macro_methods(state_machine)
            name = state_machine[:name]
            attribute = state_machine[:options][:attribute]
            state_type = state_machine[:states].any? ? state_machine[:states].first.class.to_s : 'Symbol'
            event_type = state_machine[:events].any? ? state_machine[:events].first.class.to_s : 'Symbol'
            
            # Access to class-level state machine list
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "state_machines", :class))
            m.docstring = [
              "Gets the current list of state machines defined for this class.",
              "@return [Hash] The hash of state machines mapping <tt>:attribute</tt> => +machine+"
            ]
            
            # Human state name lookup
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "human_#{name}_name", :class))
            m.docstring = [
              "Gets the humanized name for the given state.",
              "@param [#{state_type}] state The state to look up",
              "@return [String] The human state name"
            ]
            m.parameters = ["state"]
            
            # Human event name lookup
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "human_#{name}_event_name", :class))
            m.docstring = [
              "Gets the humanized name for the given event.",
              "@param [#{event_type}] event The event to look up",
              "@return [String] The human event name"
            ]
            m.parameters = ["event"]
            
            # Fire parallel events
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "fire_events"))
            m.docstring = [
              "Runs one or more events in parallel.",
              "@param [Array] events The list of events to fire",
              "@return [Boolean] +true+ if all events succeeded, otherwise +false+"
            ]
            m.parameters = ["*events"]
            
            # Fire parallel events (raises exceptions)
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "fire_events!"))
            m.docstring = [
              "Run one or more events in parallel, raising an exception if any fail.",
              "@param [Array] events The list of events to fire",
              "@return [Boolean] +true+ if all events succeeded",
              "@raise [StateMachine::InvalidTransition] If any of the events fail"
            ]
            m.parameters = ["*events"]
            
            # Machine attribute getter
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, attribute))
            m.docstring = [
              "Gets the current value for the machine",
              "@return The attribute value"
            ]
            
            # Machine attribute setter
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "#{attribute}="))
            m.docstring = [
              "Sets the current value for the machine",
              "@param new_#{attribute} The new value to set"
            ]
            m.parameters = ["new_#{attribute}"]
            
            # Presence query
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "#{name}?"))
            m.docstring = [
              "Checks the given state name against the current state.",
              "@param [#{state_type}] state_name The name of the state to check",
              "@return [Boolean] True if they are the same state, otherwise false",
              "@raise [IndexError] If the state name is invalid"
            ]
            m.parameters = ["state_name"]
            
            # Internal state name
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "#{name}_name"))
            m.docstring = [
              "Gets the name of the state for the current value.",
              "@return [#{state_type}] The name of the state"
            ]
            
            # Human state name
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "human_#{name}_name"))
            m.docstring = [
              "Gets the human-readable name of the state for the current value.",
              "@return [String] The human-readable state name"
            ]
            
            # Available events
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "#{name}_events"))
            m.docstring = [
              "Gets the list of events that can be fired on the current object's state (uses the *unqualified* event names)",
              "@param [Hash] requirements The transition requirements to test against",
              "@option requirements [#{state_type}] :from (the current state) One or more states being transitioned from",
              "@option requirements [#{state_type}] :to One or more states being transitioned to",
              "@option requirements [#{event_type}] :on One or more events that fire the transition",
              "@option requirements [Boolean] :guard Whether to guard transitions with conditionals",
              "@return [Array] The list of event names"
            ]
            m.parameters = [["requirements", "{}"]]
            
            # Availabel transitions
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "#{name}_transitions"))
            m.docstring = [
              "Gets the list of transitions that can be made on the current object's state",
              "@param [Hash] requirements The transition requirements to test against",
              "@option requirements [#{state_type}] :from (the current state) One or more states being transitioned from",
              "@option requirements [#{state_type}] :to One or more states being transitioned to",
              "@option requirements [#{event_type}] :on One or more events that fire the transition",
              "@option requirements [Boolean] :guard Whether to guard transitions with conditionals",
              "@return [Array] The list of StateMachine::Transition instances"
            ]
            m.parameters = [["requirements", "{}"]]
            
            # Available transition paths
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "#{name}_paths"))
            m.docstring = [
              "Gets the list of sequences of transitions that can be run from the current object's state",
              "@param [Hash] requirements The transition requirements to test against",
              "@option requirements [#{state_type}] :from (the current state) The initial state to start from",
              "@option requirements [#{state_type}] :to The target end state",
              "@option requirements [Boolean] :deep Whether to enable deep searches for the target state",
              "@option requirements [Boolean] :guard Whether to guard transitions with conditionals",
              "@return [StateMachine::PathCollection] The collection of paths"
            ]
            m.parameters = [["requirements", "{}"]]
            
            # Generic even fire
            register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "fire_#{name}_event"))
            m.docstring = [
              "Fires an arbitrary event with the given argument list",
              "@param [#{event_type}] event The name of the event to fire",
              "@param args Optional argument to include in the transition",
              "@return [Boolean] +true+ if the event succeeds, otherwise +false+"
            ]
            m.parameters = ["event", "*args"]
          end
          
          # Defines auto-generated event methods for the given machine
          def define_event_methods(state_machine)
            state_machine[:events].each do |name|
              name_type = name.class.to_s
              qualified_name = state_machine[:options][:namespace] ? "#{state_machine[:options][:namespace]}_#{name}" : name
              
              # Event query
              register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "can_#{qualified_name}?"))
              m.docstring = [
                "Checks whether the event can be fired.",
                "@param [Hash] requirements The transition requirements to test against",
                "@option requirements [#{name_type}] :from (the current state) One or more states being transitioned from",
                "@option requirements [#{name_type}] :to One or more states being transitioned to",
                "@option requirements [Boolean] :guard Whether to guard transitions with conditionals",
                "@return [Boolean] +true+ if the event can be fired, otherwise +false+"
              ]
              m.parameters = [["requirements", "{}"]]
              
              # Event transition
              register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "#{qualified_name}_transition"))
              m.docstring = [
                "Gets the next transition that would be performed if the event were to be fired.",
                "@param [Hash] requirements The transition requirements to test against",
                "@option requirements [#{name_type}] :from (the current state) One or more states being transitioned from",
                "@option requirements [#{name_type}] :to One or more states being transitioned to",
                "@option requirements [Boolean] :guard Whether to guard transitions with conditionals",
                "@return [StateMachine::Transition] The transition that would be performed or +nil+"
              ]
              m.parameters = [["requirements", "{}"]]
              
              # Fire event
              register(m = ::YARD::CodeObjects::MethodObject.new(namespace, qualified_name))
              m.docstring = [
                "Fires the event, transitioning from the current state to the next valid state.",
                "@param [Array] args Optional arguments to include in transition callbacks",
                "@return [Boolean] +true+ if the transition succeeds, otherwise +false+"
              ]
              m.parameters = ["*args"]
              
              # Fire event (raises exception)
              register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "#{qualified_name}!"))
              m.docstring = [
                "Fires the event, raising an exception if it fails.",
                "@param [Array] args Optional arguments to include in transition callbacks",
                "@return [Boolean] +true+ if the transition succeeds",
                "@raise [StateMachine::InvalidTransition] If the transition fails"
              ]
              m.parameters = ["*args"]
            end
          end
          
          # Defines auto-generated state methods for the given machine
          def define_state_methods(state_machine)
            state_machine[:states].compact.each do |name|
              name_type = name.class.to_s
              qualified_name = state_machine[:options][:namespace] ? "#{state_machine[:options][:namespace]}_#{name}" : name
              
              # State query
              register(m = ::YARD::CodeObjects::MethodObject.new(namespace, "#{qualified_name}?"))
              m.docstring = [
                "Checks whether #{name.inspect} is the current state.",
                "@return [Boolean] +true+ if this is the current state, otherwise +false+"
              ]
            end
          end
      end
    end
  end
end
