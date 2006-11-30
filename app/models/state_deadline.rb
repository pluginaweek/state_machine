#
class StateDeadline < ActiveRecord::Base
  validates_presence_of :state_id
  validates_presence_of :stateful_id
end