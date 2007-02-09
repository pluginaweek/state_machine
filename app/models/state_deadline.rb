#
class StateDeadline < ActiveRecord::Base
  belongs_to  :state
  belongs_to  :stateful,
                :polymorphic => true
  
  validates_presence_of :state_id,
                        :stateful_id,
                        :stateful_type
  
  # Has the deadline passed?
  def passed?
    deadline <= Time.now
  end
end