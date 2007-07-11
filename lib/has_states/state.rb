module PluginAWeek #:nodoc:
  module Has #:nodoc:
    module States #:nodoc:
      # A state stores information about the past; i.e. it reflects the input
      # changes from the system start to the present moment.
      class State
        attr_reader :record
        delegate    :name,
                    :id,
                      :to => :record
        
        def initialize(record, options) #:nodoc:
          options.symbolize_keys!.assert_valid_keys(
            :before_enter,
            :after_enter,
            :before_exit,
            :after_exit,
            :deadline_passed_event
          )
          options.reverse_merge!(
            :deadline_passed_event => "#{record.name}_deadline_passed"
          )
          
          @record, @options = record, options
        end
        
        # Gets the name of the event that should be invoked when the state's
        # deadline has passed
        def deadline_passed_event
          "#{@options[:deadline_passed_event]}!"
        end
        
        # Indicates that the state is being entered
        def before_enter(record, *args)
          run_actions(record, args, :before_enter)
        end
        
        # Indicates that the state has been entered.  If a deadline needs to
        # be set when this state is being entered, "set_#{name}_deadline"
        # should be defined in the record's class.
        def after_enter(record, *args)
          # If the class supports deadlines, then see if we can set it now
          if record.class.use_state_deadlines && record.respond_to?("set_#{name}_deadline")
            record.send("set_#{name}_deadline")
          end
          
          run_actions(record, args, :after_enter)
        end
        
        # Indicates the the state is being exited
        def before_exit(record, *args)
          run_actions(record, args, :before_exit)
        end
        
        # Indicates the the state has been exited
        def after_exit(record, *args)
          run_actions(record, args, :after_exit)
        end
        
        private
        def run_actions(record, args, action_type) #:nodoc:
          if actions = @options[action_type]
            Array(actions).each {|action| record.eval_call(action, *args)}
          end
        end
      end
    end
  end
end