# A state represents a phase in the lifetime of a machine.  The state of a
# machine is usually what drives the functionality of systems external to the
# machine.
# 
# == State Changes
# 
# All states track when they were transitioned *to* and *from* through instances
# of the StateChange model.  You can access these state changes like so:
# 
#   >> s = State.find_by_name('parked')
#   => #<State:0x2b6f91183810 @attributes={"name"=>"parked", "id"=>"301", "human_name"=>nil, "owner_type"=>"Vehicle"}>
#   >> s.changes_from
#   => [#<StateChange:0x2b6f91176020 @attributes={"event_id"=>"302", "from_state_id"=>"301", "stateful_type"=>"Vehicle", "id"=>"3", "to_state_id"=>"302", "occurred_at"=>"2007-08-22 16:10:41", "stateful_id"=>"2"}>, ...]
#   >> s.changes_to
#   => [#<StateChange:0x2b6f9116e258 @attributes={"event_id"=>nil, "from_state_id"=>nil, "stateful_type"=>"Vehicle", "id"=>"1", "to_state_id"=>"301", "occurred_at"=>"2007-08-22 16:10:41", "stateful_id"=>"1"}>, ...]
class State < ActiveRecord::Base
  has_many  :changes_from,
              :class_name => 'StateChange',
              :foreign_key => 'from_state_id',
              :order => 'occurred_at ASC',
              :dependent => :destroy
  has_many  :changes_to,
              :class_name => 'StateChange',
              :foreign_key => 'to_state_id',
              :order => 'occurred_at ASC',
              :dependent => :destroy
  
  validates_presence_of   :name
  validates_uniqueness_of :name,
                            :scope => :owner_type
  
  # A humanized version of the name
  def human_name
    read_attribute(:human_name) || name.to_s.titleize
  end
  
  # The symbolic name of the state
  def to_sym
    name = read_attribute(:name)
    name ? name.to_sym : nil
  end
end
