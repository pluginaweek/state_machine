# An event is an observable stimulus, response, or action 
class Event < ActiveRecord::Base
  has_many                :state_changes,
                            :order => 'occurred_at ASC'
  
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