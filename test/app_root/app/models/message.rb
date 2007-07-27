class Message < ActiveRecord::Base
  has_states :initial => :pending
  
  state :pending, :deleted
  
  event :delete, :after => :destroy do
    transition_to :deleted, :from => :pending
  end
end