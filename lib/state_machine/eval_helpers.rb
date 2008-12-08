module PluginAWeek #:nodoc:
  module StateMachine
    # Provides a set of helper methods for evaluating methods within the context
    # of an object.
    module EvalHelpers
      # Evaluates one of several different types of methods within the context
      # of the given object.  Methods can be one of the following types:
      # * Symbol
      # * Method / Proc
      # * String
      # 
      # == Examples
      # 
      # Below are examples of the various ways that a method can be evaluated
      # on an object:
      # 
      #   class Person
      #     def initialize(name)
      #       @name = name
      #     end
      #     
      #     def name
      #       @name
      #     end
      #   end
      #   
      #   class PersonCallback
      #     def self.run(person)
      #       person.name
      #     end
      #   end
      # 
      #   person = Person.new('John Smith')
      #   
      #   evaluate_method(person, :name)                            # => "John Smith"
      #   evaluate_method(person, PersonCallback.method(:run))      # => "John Smith"
      #   evaluate_method(person, Proc.new {|person| person.name})  # => "John Smith"
      #   evaluate_method(person, lambda {|person| person.name})    # => "John Smith"
      #   evaluate_method(person, '@name')                          # => "John Smith"
      # 
      # == Additional arguments
      # 
      # Additional arguments can be passed to the methods being evaluated.  If
      # the method defines additional arguments other than the object context,
      # then all arguments are required.
      # 
      # For example,
      # 
      #   person = Person.new('John Smith')
      #   
      #   evaluate_method(person, lambda {|person| person.name}, 21)                              # => "John Smith"
      #   evaluate_method(person, lambda {|person, age| "#{person.name} is #{age}"}, 21)          # => "John Smith is 21"
      #   evaluate_method(person, lambda {|person, age| "#{person.name} is #{age}"}, 21, 'male')  # => ArgumentError: wrong number of arguments (3 for 2)
      def evaluate_method(object, method, *args)
        case method
          when Symbol
            method = object.method(method)
            method.arity == 0 ? method.call : method.call(*args)
          when String
            eval(method, object.instance_eval {binding})
          when Proc, Method
            method.arity == 1 ? method.call(object) : method.call(object, *args)
          else
            raise ArgumentError, 'Methods must be a symbol denoting the method to call, a string to be evaluated, or a block to be invoked'
          end
      end
    end
  end
end
