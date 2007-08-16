class Vehicle < ActiveRecord::Base
  has_states :initial => Proc.new {|vehicle| vehicle.force_idle? ? :idling : :parked}
  
  belongs_to :auto_shop
  delegate :tow_vehicle!, :fix_vehicle!, :to => :auto_shop
  
  attr_accessor :force_idle
  
  validates_presence_of :highway_id
  
  state :parked,
          :before_exit => :put_on_seatbelt,
          :after_enter => Proc.new {|vehicle| vehicle.update_attribute(:seatbelt_on, false)}
  state :idling,
        :first_gear,
        :second_gear,
        :third_gear
  state :stalled,
          :before_enter => :increase_insurance_premium
  
  event :park do
    transition_to :parked, :from => [:idling, :first_gear]
  end
  
  event :ignite do
    transition_to :stalled, :from => :stalled
    transition_to :idling, :from => :parked
  end
  
  event :idle do
    transition_to :idling, :from => :first_gear
  end
  
  event :shift_up do
    transition_to :first_gear, :from => :idling
    transition_to :second_gear, :from => :first_gear
    transition_to :third_gear, :from => :second_gear
  end
  
  event :shift_down do
    transition_to :second_gear, :from => :third_gear
    transition_to :first_gear, :from => :second_gear
  end
  
  event :crash, :after => :tow_vehicle! do
    transition_to :stalled, :from => [:first_gear, :second_gear, :third_gear],
                    :if => Proc.new {|vehicle| vehicle.auto_shop.available?}
  end
  
  event :repair, :after => :fix_vehicle! do
    transition_to :parked, :from => :stalled,
                    :if => :auto_shop_busy?
  end
  
  def force_idle?
    @force_idle
  end
  
  private
  def put_on_seatbelt
    self.seatbelt_on = true
  end
  
  def increase_insurance_premium
    update_attribute(:insurance_premium, self.insurance_premium + 100)
  end
  
  def auto_shop_busy?
    auto_shop.busy?
  end
end