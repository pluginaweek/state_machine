require 'state_machine/eval_helpers'

module StateMachine
  # Represents a type of module in which class-level methods are proxied to
  # another class, injecting a custom :if condition along with method.
  # 
  # This is used for being able to automatically include conditionals which
  # check the current state in class-level methods that have configuration
  # options.
  # 
  # == Examples
  # 
  #   class Vehicle
  #     class << self
  #       attr_accessor :validations
  #       
  #       def validate(options, &block)
  #         validations << options
  #       end
  #     end
  #     
  #     self.validations = []
  #     attr_accessor :state, :simulate
  #     
  #     def moving?
  #       self.class.validations.all? {|validation| validation[:if].call(self)}
  #     end
  #   end
  # 
  # In the above class, a simple set of validation behaviors have been defined.
  # Each validation consists of a configuration like so:
  # 
  #   Vehicle.validate :unless => :simulate
  #   Vehicle.validate :if => lambda {|vehicle| ...}
  # 
  # In order to scope conditions, a condition proxy can be created to the
  # Vehicle class.  For example,
  # 
  #   proxy = StateMachine::ConditionProxy.new(Vehicle, lambda {|vehicle| vehicle.state == 'first_gear'})
  #   proxy.validate(:unless => :simulate)
  #   
  #   vehicle = Vehicle.new     # => #<Vehicle:0xb7ce491c @simulate=nil, @state=nil>
  #   vehicle.moving?           # => false
  #   
  #   vehicle.state = 'first_gear'
  #   vehicle.moving?           # => true
  #   
  #   vehicle.simulate = true
  #   vehicle.moving?           # => false
  class ConditionProxy < Module
    include EvalHelpers
    
    # Creates a new proxy to the given class, merging in the given condition
    def initialize(klass, condition)
      @klass = klass
      @condition = condition
    end
    
    # Hooks in condition-merging to methods that don't exist in this module
    def method_missing(*args, &block)
      # Get the configuration
      if args.last.is_a?(Hash)
        options = args.last
      else
        args << options = {}
      end
      
      # Get any existing condition that may need to be merged
      if_condition = options.delete(:if)
      unless_condition = options.delete(:unless)
      
      # Provide scope access to configuration in case the block is evaluated
      # within the object instance
      proxy = self
      proxy_condition = @condition
      
      # Replace the configuration condition with the one configured for this
      # proxy, merging together any existing conditions
      options[:if] = lambda do |*args|
        # Block may be executed within the context of the actual object, so
        # it'll either be the first argument or the executing context
        object = args.first || self
        
        proxy.evaluate_method(object, proxy_condition) &&
        Array(if_condition).all? {|condition| proxy.evaluate_method(object, condition)} &&
        !Array(unless_condition).any? {|condition| proxy.evaluate_method(object, condition)}
      end
      
      # Evaluate the method on the original class with the condition proxied
      # through
      @klass.send(*args, &block)
    end
  end
end
