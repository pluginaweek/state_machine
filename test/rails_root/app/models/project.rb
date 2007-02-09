class Project < ActiveRecord::Base
  has_many :state_deadlines
  has_many :state_changes
  
  belongs_to :state
end