# An event is an observable stimulus, response, or action 
class Event < ActiveRecord::Base
  validates_presence_of   :name,
                          :long_description
  validates_uniqueness_of :name
  
  #
  def short_description
    read_attribute(:short_description) || name.titleize
  end
end