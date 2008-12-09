class Switch
  state_machine do
    event :turn_on do
      transition :to => 'on', :from => 'off'
    end
    
    event :turn_off do
      transition :to => 'off', :from => 'on'
    end
  end
end
