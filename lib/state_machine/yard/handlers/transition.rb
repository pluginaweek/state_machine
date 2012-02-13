module StateMachine
  module YARD
    module Handlers
      # Handles and processes #transition
      class Transition < Base
        handles method_call(:transition)
        
        def process
          if owner && owner.is_a?(Hash) && [:state_machine, :state, :event].include?(owner[:type])
            transitions = extract_transitions(statement.parameters.first)
            transitions.each do |transition|
              case owner[:type]
              when :state
                # Set the from / to state as the context depending on what the
                # transition has already specified
                transition[transition[:from] ? :to : :from] = owner[:name]
                state_machine = owner[:state_machine]
              when :event
                # Set the event as the context
                transition[:on] = owner[:name]
                state_machine = owner[:state_machine]
              else
                state_machine = owner
              end
              
              # Add events
              [:on, :except_on].each do |key|
                state_machine[:events].concat([transition[key]].flatten) if transition.include?(key)
              end
              
              # Add states
              [:from, :except_from, :to, :except_to].each do |key|
                state_machine[:states].concat([transition[key]].flatten) if transition.include?(key)
              end
              
              # Track transitions
              state_machine[:transitions] << transition
            end
          end
        end

        private
          # Extracts the transition from the given node
          def extract_transitions(ast)
            transitions = []
            
            reserved_keys = %w(from to on except_from except_to except_on if unless)
            if ast.children.all? {|assoc| assoc[0].type == :symbol_literal && reserved_keys.include?(assoc[0].jump(:ident).source)}
              # Using old syntax (:from => :state1, :to => :state2, :on => :event1)
              transition = {}
              ast.children.each do |assoc|
                key = assoc[0].jump(:ident).source.to_sym
                
                # Skip conditionals
                next if [:if, :unless].include?(key)
                
                transition[key] = extract_strings_or_symbols(assoc[1])
              end
              transitions << transition
            else
              event_requirements = nil
              
              # Using new syntax (:state1 => :state2, :state3 => :state4)
              ast.children.each do |assoc|
                # Skip conditionals
                next if %w(if unless).include?(assoc[0].jump(:ident))
                
                # Set from / to state
                transition = {}
                transition.merge!(extract_state_requirement(assoc[0], :from))
                transition.merge!(extract_state_requirement(assoc[1], :to))
                
                if [[:on], [:except_on]].include?(transition[:from])
                  # Track the event requirements
                  event_requirements = {transition[:from][0] => transition[:to] || transition[:except_to]}
                else
                  # Add the transition
                  transitions << transition
                end
              end
              
              # Merge in event requirements
              transitions.each do |transition|
                transition.merge!(event_requirements)
              end if event_requirements
            end
            
            transitions
          end
          
          # Extracts the statement requirement from the given node
          def extract_state_requirement(ast, option)
            case ast.type
            when :symbol_literal, :string_literal, :array
              {option => extract_node_names(ast)}
            when :binary
              {:"except_#{option}" => extract_node_names(ast.children.last)}
            else
              {}
            end
          end
      end
    end
  end
end
