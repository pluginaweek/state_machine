module StateMachine
  # Provides an alternate syntax for defining state machines
  #
  # For example,
  #
  #   class Vehicle
  #     state_machine :initial => :parked, :action => :save, :syntax => :alternate do
  #       state :parked do
  #         event :ignite, :to => :idling, :if => :have_keys?
  #       end
  #
  #       state :idling do
  #         event :park, :to => :parked, :unless => :no_spots?
  #       end
  #     end
  #   end
  #
  # Instead of,
  #
  #   class Vehicle
  #     state_machine :initial => :parked, :action => :save do
  #       event :ignite do
  #         transition :parked => :idling, :if => :have_keys?
  #       end
  #
  #       event :park do
  #         transition :idling => :parked, :unless => :no_spots?
  #       end
  #     end
  #   end
  #
  # Also supports usage of :any, :all, and :same as valid states.
  class AlternateMachine
    include MatcherHelpers

    def initialize(&block)
      @queued_sends = []
      instance_eval(&block) if block_given?
    end

    def state(*args, &block)
      @from_state = args.first
      instance_eval(&block) if block_given?
    end

    def event(event_name, options = {})
      to_state = options.delete(:to)
      @queued_sends << [event_name, @from_state, to_state, options]
    end

    def to_state_machine
      queued_sends = @queued_sends
      lambda {
        queued_sends.each do |args|
          case args.length
          when 2 # method_missing
            args, block = args
            send(*args, &block)
          when 4 # event transition
            event_name, from, to, options = args
            event event_name do
              transition options.merge(from => to)
            end
          end
        end
      }
    end

    def method_missing(*args, &block)
      @queued_sends << [args, block]
    end
  end
end