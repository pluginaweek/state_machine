# Represents a change from one state to another via a stimulus (event)
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
    if record_timestamps
      t = self.class.default_timezone == :utc ? Time.now.utc : Time.now
      write_attribute('occurred_at', t)
    end
    create_without_custom_timestamps
  end
  alias_method_chain :create, :custom_timestamps
end