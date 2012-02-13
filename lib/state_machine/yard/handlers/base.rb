module StateMachine
  module YARD
    module Handlers
      # Handles and processes nodes
      class Base < ::YARD::Handlers::Ruby::Base
        private
          # Extracts the value from the node as either a string or symbol
          def extract_node_name(ast)
            if ast.type == :string_literal
              ast.jump(:tstring_content).source
            else
              ast.jump(:ident).source.to_sym
            end
          end
          
          # Extracts the values from the node as either strings or symbols.
          # If the node isn't an array, it'll be converted to an array.
          def extract_node_names(ast)
            if [nil, :array].include?(ast.type)
              ast.children.map {|child| extract_node_name(child)}
            else
              [extract_node_name(ast)]
            end
          end
      end
    end
  end
end
