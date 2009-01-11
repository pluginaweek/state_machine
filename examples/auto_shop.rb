class AutoShop
  state_machine :initial => :available do
    event :tow_vehicle do
      transition :to => :busy, :from => :available
    end
    
    event :fix_vehicle do
      transition :to => :available, :from => :busy
    end
  end
end
