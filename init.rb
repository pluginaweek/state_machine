require_plugin 'dry_transaction_rollbacks'

require 'acts_as_state_machine'

ActiveRecord::Base.class_eval do
  include PluginAWeek::Acts::StateMachine
end
