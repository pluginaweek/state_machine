class Switch < ActiveRecord::Base
  has_states :initial => :off, :record_changes => false
  
  state :on, :off
  
  event :turn_on do
    transition_to :on, :from => :off
  end
  
  event :turn_off do
    transition_to :off, :from => :on
  end
end