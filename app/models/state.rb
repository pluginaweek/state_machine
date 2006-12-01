# 
class State < ActiveRecord::Base
  validates_presence_of   :name,
                          :long_description
  validates_uniqueness_of :name
  
  class << self
    #
    def migrate_up
      model = parent
      if !model.content_columns.any? {|c| c.name == :state_id}
        self.connection.add_column(model.table_name, :state_id, :integer, :null => false, :default => nil, :unsigned => true)
      end
    end
    
    #
    def migrate_down
      model = parent
      self.connection.remove_column(model.table_name, :state_id)
    end
  end
  
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