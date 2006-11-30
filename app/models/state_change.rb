#
class StateChange < ActiveRecord::Base
  validates_presence_of :event_id
  validates_presence_of :stateful_id
  validates_presence_of :to_state_id
end