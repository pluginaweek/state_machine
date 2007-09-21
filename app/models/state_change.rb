# Represents a change from one state to another via a stimulus (event).  A state
# change may be a loopback, in which case the from state and to state are the
# same.
# 
# == Timestamps
# 
# Every state change is timestamped with the +occurred_at+ attribute.  Since
# this is not the standard name for timestamps (such as +updated_at+ or
# +created_at+), there is a create hook which will automatically set the value for
# +occurred_at+.
class StateChange < ActiveRecord::Base
  belongs_to  :event
  belongs_to  :from_state,
                :class_name => 'State',
                :foreign_key => 'from_state_id'
  belongs_to  :to_state,
                :class_name => 'State',
                :foreign_key => 'to_state_id'
  belongs_to  :stateful,
                :polymorphic => true
  
  validates_presence_of :stateful_id,
                        :stateful_type,
                        :to_state_id
  
  def create_with_custom_timestamps #:nodoc:
    # Record when the state change occurred if this model is enabled for
    # timestamps
    if record_timestamps
      occurred_at = self.class.default_timezone == :utc ? Time.now.utc : Time.now
      write_attribute('occurred_at', occurred_at)
    end
    create_without_custom_timestamps
  end
  alias_method_chain :create, :custom_timestamps
end
