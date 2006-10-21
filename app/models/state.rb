# 
#
class State < ActiveRecord::Base
  validates_presence_of   :name,
                          :long_description
  
  validates_length_of     :name, :within => 1..50
  validates_length_of     :long_description, :within => 1..1024
  
  validates_uniqueness_of :name
  
  has_many                :changes, :class_name => 'StateChange'
  has_many                :deadlines, :class_name => 'StateDeadline'
  
  class << self
    def migrate_up
      model = parent
      if !model.content_columns.find { |c| [:state_id].include?(c.name) }
        self.connection.add_column model.table_name, :state_id, :integer, :null => false, :unsigned => true
      end
    end
    
    def migrate_down
      model = parent
      self.connection.remove_column_if_exists model.table_name, :state_id
    end
  end
  
  #
  #
  def short_description
    read_attribute[:short_description] || name.titleize
  end
end