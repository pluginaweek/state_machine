# 
class State < ActiveRecord::Base
  validates_presence_of   :name,
                          :long_description
  validates_uniqueness_of :name
  
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