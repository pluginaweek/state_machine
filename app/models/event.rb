#
#
class Event < ActiveRecord::Base
  validates_presence_of   :name,
                          :long_description
  
  validates_length_of     :name, :within => 1..50
  validates_length_of     :long_description, :within => 1..1024
  
  validates_uniqueness_of :name
  
  has_many                :state_changes
  
  #
  #
  def short_description
    read_attribute[:short_description] || name.titleize
  end
end