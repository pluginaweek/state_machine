class TrafficLight
  state_machine :initial => :stop do
    event :cycle do
      transition :to => :proceed, :from => :stop
      transition :to => :caution, :from => :proceed
      transition :to => :stop, :from => :caution
    end
  end
end
