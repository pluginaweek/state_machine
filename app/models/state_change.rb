#
#
class StateChange < ActiveRecord::Base
  belongs_to  :event
  belongs_to  :from_state,
                :class_name => 'State',
                :foreign_key => 'to_state_id'
  belongs_to  :to_state,
                :class_name => 'State',
                :foreign_key => 'to_state_id'
end