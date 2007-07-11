class Switch < ActiveRecord::Base
  has_states :initial => :off
  
  state :on
  state :off
  
  event :turn_on do
    transition_to :on, :from => :off
  end
  
  event :turn_off do
    transition_to :off, :from => :on
  end
end