class Car < Vehicle
  state :backing_up
  
  event :reverse do
    transition_to :backing_up, :from => [:parked, :idling, :first_gear]
  end
  
  event :park do
    transition_to :parked, :from => :backing_up
  end
  
  event :idle do
    transition_to :idling, :from => :backing_up
  end
  
  event :shift_up do
    transition_to :first_gear, :from => :backing_up
  end
end