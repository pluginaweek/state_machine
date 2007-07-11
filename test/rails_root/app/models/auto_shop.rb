class AutoShop < ActiveRecord::Base
  has_states :initial => :available
  
  state :available,
    :after_exit => :increment_customers
  state :busy,
    :after_exit => :decrement_customers
  
  event :tow_vehicle do
    transition_to :busy, :from => :available
  end
  
  event :fix_vehicle do
    transition_to :available, :from => :busy
  end
  
  def increment_customers
    update_attribute(:num_customers, self.num_customers + 1)
  end
  
  def decrement_customers
    update_attribute(:num_customers, self.num_customers - 1)
  end
end