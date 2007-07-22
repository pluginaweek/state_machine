# A state represents a phase in the lifetime of a machine
class State < ActiveRecord::Base
  has_many  :changes,
              :class_name => 'StateChange',
              :foreign_key => 'to_state_id',
              :order => 'occurred_at ASC',
              :dependent => :destroy
  has_many  :deadlines,
              :class_name => 'StateDeadline',
              :dependent => :destroy
  
  validates_presence_of   :name
  validates_uniqueness_of :name,
                            :scope => :owner_type
  
  # The symbolic name of the state
  def name
    name = read_attribute(:name)
    name ? name.to_sym : name
  end
  
  # A humanized version of the name
  def human_name
    read_attribute(:human_name) || name.to_s.titleize
  end
end