module PluginAWeek #:nodoc:
  module StateMachine
    # Provides a set of helper methods for making assertions about content of
    # various objects
    module Assertions
      # Validates that all keys in the given hash *only* includes the specified
      # valid keys.  If any invalid keys are found, an ArgumentError will be
      # raised.
      #
      # == Examples
      # 
      #   options = {:name => 'John Smith', :age => 30}
      #   
      #   assert_valid_keys(options, :name)           # => ArgumentError: Invalid key(s): age
      #   assert_valid_keys(options, 'name', 'age')   # => ArgumentError: Invalid key(s): age, name
      #   assert_valid_keys(options, :name, :age)     # => nil
      def assert_valid_keys(hash, *valid_keys)
        invalid_keys = hash.keys - valid_keys
        raise ArgumentError, "Invalid key(s): #{invalid_keys.join(", ")}" unless invalid_keys.empty?
      end
    end
  end
end
