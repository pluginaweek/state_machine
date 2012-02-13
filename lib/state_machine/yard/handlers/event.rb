module StateMachine
  module YARD
    module Handlers
      # Handles and processes #event
      class Event < Base
        handles method_call(:event)
        
        def process
          if owner && owner.is_a?(Hash) && owner[:type] == :state_machine
            event = {:type => :event, :state_machine => owner}
            names = extract_node_names(statement.parameters(false))
            
            names.each do |name|
              # Track the event
              owner[:events] << name
              
              # Parse the block
              parse_block(statement.last.last, :owner => event.merge(:name => name))
            end
          end
        end
      end
    end
  end
end
