class Vehicle
  state_machine :initial => :parked do
    event :park do
      transition :to => :parked, :from => [:idling, :first_gear]
    end
    
    event :ignite do
      transition :to => :stalled, :from => :stalled
      transition :to => :idling, :from => :parked
    end
    
    event :idle do
      transition :to => :idling, :from => :first_gear
    end
    
    event :shift_up do
      transition :to => :first_gear, :from => :idling
      transition :to => :second_gear, :from => :first_gear
      transition :to => :third_gear, :from => :second_gear
    end
    
    event :shift_down do
      transition :to => :second_gear, :from => :third_gear
      transition :to => :first_gear, :from => :second_gear
    end
    
    event :crash do
      transition :to => :stalled, :from => [:first_gear, :second_gear, :third_gear]
    end
    
    event :repair do
      transition :to => :parked, :from => :stalled
    end
  end
end
