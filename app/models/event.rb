# An event is an observable stimulus, response, or action.  The invociation of
# an event can result in the transition from one state to another.
# 
# == State Changes
# 
# All events track when they were invoked through instances of the StateChange
# model.  You can access these state changes like so:
# 
#   >> e = Event.find_by_name('ignite')
#   => #<Event:0x2b6f911b6710 @attributes={"name"=>"ignite", "id"=>"302", "human_name"=>nil, "owner_type"=>"Vehicle"}>
#   >> e.state_changes
#   => [#<StateChange:0x2b6f91190e70 @attributes={"event_id"=>"302", "from_state_id"=>"301", "stateful_type"=>"Vehicle", "id"=>"3", "to_state_id"=>"302", "occurred_at"=>"2007-08-22 16:10:41", "stateful_id"=>"2"}>, ...]
class Event < ActiveRecord::Base
  has_many  :state_changes,
              :order => 'occurred_at ASC',
              :dependent => :destroy
  
  validates_presence_of   :name
  validates_uniqueness_of :name,
                            :scope => :owner_type  
  
  # A humanized version of the name
  def human_name
    read_attribute(:human_name) || name.to_s.titleize
  end
  
  # The symbolic name of the event
  def to_sym
    name = read_attribute(:name)
    name ? name.to_sym : name
  end
end
