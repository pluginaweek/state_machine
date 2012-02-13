module StateMachine
  module YARD
    module Handlers
      # Handles and processes #state
      class State < Base
        handles method_call(:state)
        
        def process
          if owner && owner.is_a?(Hash) && owner[:type] == :state_machine
            state = {:type => :state, :state_machine => owner}
            names = extract_node_names(statement.parameters(false))
            
            names.each do |name|
              # Track the state
              owner[:states] << name
              
              # Parse the block
              parse_block(statement.last.last, :owner => state.merge(:name => name))
            end
          end
        end
      end
    end
  end
end
