class Switch < ActiveRecord::Base
  acts_as_state_machine :initial => :off,
                          :use_deadlines => true
  
  state :on
  state :off
  
  event :turn_on do
    transition_to :on, :from => :off
  end
  
  event :turn_off do
    transition_to :off, :from => :on
  end
end