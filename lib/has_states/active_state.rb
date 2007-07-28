module PluginAWeek #:nodoc:
  module Has #:nodoc:
    module States #:nodoc:
      # An active state is one which can be used in a model.
      class ActiveState
        attr_accessor :owner_class
        
        # The state which is being represented
        attr_reader :record
        
        delegate :id, :to => '@record'
        
        def initialize(owner_class, record, options = {})
          options.assert_valid_keys(
            :before_enter,
            :after_enter,
            :before_exit,
            :after_exit
          )
          
          @owner_class, @record, @options = owner_class, record, options
          
          add_state_checking
          add_state_change_checking
          add_callbacks
          update_state_extension
        end
        
        def respond_to?(symbol, include_priv = false) #:nodoc:
          super || @record.respond_to?(symbol, include_priv)
        end
        
        def hash #:nodoc:
          @record.hash
        end
        
        def ==(obj) #:nodoc:
          @record == (obj.is_a?(State) ? obj : obj.record)
        end
        alias :eql? :==
        
        private
        def method_missing(method, *args, &block) #:nodoc:
          @record.send(method, *args, &block) if @record
        end
        
        def add_state_checking
          @owner_class.class_eval <<-end_eval
            def #{name}?
              state_id == #{id}
            end
          end_eval
        end
        
        # Add checking when the change in state occurred
        def add_state_change_checking
          if @owner_class.record_state_changes
            @owner_class.class_eval <<-end_eval
              def #{name}_at(count = :last)
                if [:first, :last].include?(count)
                  state_change = state_changes.find_by_to_state_id(#{id}, :order => "occurred_at \#{count == :first ? 'ASC' : 'DESC'}")
                  state_change.occurred_at if state_change
                else
                  state_changes.find_all_by_to_state_id(#{id}, :order => 'occurred_at ASC').map(&:occurred_at)
                end
              end
            end_eval
          end
        end
        
        # Adds the callbacks for before and after states are entered/exited
        def add_callbacks
          [:before_enter, :after_enter, :before_exit, :after_exit].each do |type|
            callback = "#{type}_#{name}"
            @owner_class.class_eval <<-end_eval
              def self.#{callback}(*callbacks, &block)
                callbacks << block if block_given?
                write_inheritable_array(:#{callback}, callbacks)
              end
            end_eval
            
            @owner_class.send(callback, @options[type]) if @options[type]
          end
        end
        
        # Update the state extension module to support looking up records
        # of this object by state in a has_many association
        def update_state_extension
          @owner_class::StateExtension.module_eval <<-end_eval
            def #{name}(*args)
              with_scope(:find => {:conditions => ["\#{aliased_table_name}.state_id = ?", #{id}]}) do
                find(args.first.is_a?(Symbol) ? args.shift : :all, *args)
              end
            end
            
            def #{name}_count(*args)
              with_scope(:find => {:conditions => ["\#{aliased_table_name}.state_id = ?", #{id}]}) do
                count(*args)
              end
            end
          end_eval
        end
      end
    end
  end
end