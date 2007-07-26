module PluginAWeek #:nodoc:
  module Has #:nodoc:
    module States #:nodoc:
      # An active event is one which can be used in a model.
      module ActiveState
        def dup #:nodoc:
          event = super
          event.extend PluginAWeek::Has::States::ActiveState
          event
        end
      end
    end
  end
end