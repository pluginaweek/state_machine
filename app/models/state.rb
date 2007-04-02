# 
class State < ActiveRecord::Base
  has_many                :changes,
                            :class_name => 'StateChange',
                            :foreign_key => 'to_state_id',
                            :order => 'occurred_at ASC'
  has_many                :deadlines,
                            :class_name => 'StateDeadline'
  
  validates_presence_of   :name,
                          :long_description
  validates_uniqueness_of :name,
                            :scope => :owner_type
  
  # 
  def name
    name = read_attribute(:name)
    name ? name.to_sym : name
  end
  
  # 
  def short_description
    read_attribute(:short_description) || name.to_s.titleize
  end
end