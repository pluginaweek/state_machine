module PluginAWeek #:nodoc:
  module Has #:nodoc:
    module States #:nodoc:
      # 
      module StateExtension
        # 
        def find_in_states(number, *args)
          @reflection.klass.with_state_scope(args) do |options|
            find(number, options)
          end
        end
      end
    end
  end
end