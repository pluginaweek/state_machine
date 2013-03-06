class Switch
  def self.name
    @name ||= "Switch_#{rand(1000000)}"
  end
  
  state_machine do
    event :turn_on do
      transition all => :on
    end
    
    event :turn_off do
      transition all => :off
    end
  end
end
