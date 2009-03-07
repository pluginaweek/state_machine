# Load each available integration
Dir["#{File.dirname(__FILE__)}/integrations/*.rb"].sort.each do |path|
  require "state_machine/integrations/#{File.basename(path)}"
end

module StateMachine
  # Integrations allow state machines to take advantage of features within the
  # context of a particular library.  This is currently most useful with
  # database libraries.  For example, the various database integrations allow
  # state machines to hook into features like:
  # * Saving
  # * Transactions
  # * Observers
  # * Scopes
  # * Callbacks
  # * Validation errors
  # 
  # This type of integration allows the user to work with state machines in a
  # fashion similar to other object models in their application.
  # 
  # The integration interface is loosely defined by various unimplemented
  # methods in the StateMachine::Machine class.  See that class or the various
  # built-in integrations for more information about how to define additional
  # integrations.
  module Integrations
    # Attempts to find an integration that matches the given class.  This will
    # look through all of the built-in integrations under the StateMachine::Integrations
    # namespace and find one that successfully matches the class.
    # 
    # == Examples
    # 
    #   class Vehicle
    #   end
    #   
    #   class ARVehicle < ActiveRecord::Base
    #   end
    #   
    #   class DMVehicle
    #     include DataMapper::Resource
    #   end
    #   
    #   class SequelVehicle < Sequel::Model
    #   end
    #   
    #   StateMachine::Integrations.match(Vehicle)         # => nil
    #   StateMachine::Integrations.match(ARVehicle)       # => StateMachine::Integrations::ActiveRecord
    #   StateMachine::Integrations.match(DMVehicle)       # => StateMachine::Integrations::DataMapper
    #   StateMachine::Integrations.match(SequelVehicle)   # => StateMachine::Integrations::Sequel
    def self.match(klass)
      if integration = constants.find {|name| const_get(name).matches?(klass)}
        find(integration)
      end
    end
    
    # Finds an integration with the given name.  If the integration cannot be
    # found, then a NameError exception will be raised.
    # 
    # == Examples
    # 
    #   StateMachine::Integrations.find(:active_record)   # => StateMachine::Integrations::ActiveRecord
    #   StateMachine::Integrations.find(:data_mapper)     # => StateMachine::Integrations::DataMapper
    #   StateMachine::Integrations.find(:sequel)          # => StateMachine::Integrations::Sequel
    #   StateMachine::Integrations.find(:invalid)         # => NameError: wrong constant name Invalid
    def self.find(name)
      const_get(name.to_s.gsub(/(?:^|_)(.)/) {$1.upcase})
    end
  end
end
