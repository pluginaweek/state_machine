require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AutoShop
  attr_accessor :num_customers
  
  def initialize
    @num_customers = 0
  end
  
  state_machine :initial => 'available' do
    after_transition :from => 'available', :do => :increment_customers
    after_transition :from => 'busy', :do => :decrement_customers
    
    event :tow_vehicle do
      transition :to => 'busy', :from => 'available'
    end
    
    event :fix_vehicle do
      transition :to => 'available', :from => 'busy'
    end
  end
  
  # Is the Auto Shop available for new customers?
  def available?
    state == 'available'
  end
  
  # Is the Auto Shop currently not taking new customers?
  def busy?
    state == 'busy'
  end
  
  # Increments the number of customers in service
  def increment_customers
    self.num_customers += 1
  end
  
  # Decrements the number of customers in service
  def decrement_customers
    self.num_customers -= 1
  end
end

class Vehicle
  attr_accessor :auto_shop, :seatbelt_on, :insurance_premium, :force_idle, :callbacks, :saved
  
  def initialize(attributes = {})
    attributes = {
      :auto_shop => AutoShop.new,
      :seatbelt_on => false,
      :insurance_premium => 50,
      :force_idle => false,
      :callbacks => [],
      :saved => false
    }.merge(attributes)
    
    attributes.each {|attr, value| send("#{attr}=", value)}
  end
  
  # Defines the state machine for the state of the vehicled
  state_machine :initial => lambda {|vehicle| vehicle.force_idle ? 'idling' : 'parked'}, :action => :save do
    before_transition :from => 'parked', :do => :put_on_seatbelt
    before_transition :to => 'stalled', :do => :increase_insurance_premium
    after_transition :to => 'parked', :do => lambda {|vehicle| vehicle.seatbelt_on = false}
    after_transition :on => 'crash', :do => :tow
    after_transition :on => 'repair', :do => :fix
    
    # Callback tracking for initial state callbacks
    after_transition :to => 'parked', :do => lambda {|vehicle| vehicle.callbacks << 'before_enter_parked'}
    before_transition :to => 'idling', :do => lambda {|vehicle| vehicle.callbacks << 'before_enter_idling'}
    
    event :park do
      transition :to => 'parked', :from => %w(idling first_gear)
    end
    
    event :ignite do
      transition :to => 'stalled', :from => 'stalled'
      transition :to => 'idling', :from => 'parked'
    end
    
    event :idle do
      transition :to => 'idling', :from => 'first_gear'
    end
    
    event :shift_up do
      transition :to => 'first_gear', :from => 'idling'
      transition :to => 'second_gear', :from => 'first_gear'
      transition :to => 'third_gear', :from => 'second_gear'
    end
    
    event :shift_down do
      transition :to => 'second_gear', :from => 'third_gear'
      transition :to => 'first_gear', :from => 'second_gear'
    end
    
    event :crash do
      transition :to => 'stalled', :from => %w(first_gear second_gear third_gear), :if => lambda {|vehicle| vehicle.auto_shop.available?}
    end
    
    event :repair do
      transition :to => 'parked', :from => 'stalled', :if => :auto_shop_busy?
    end
  end
  
  def save
    @saved = true
  end
  
  def new_record?
    @saved == false
  end
  
  # Tows the vehicle to the auto shop
  def tow
    auto_shop.tow_vehicle
  end
  
  # Fixes the vehicle; it will no longer be in the auto shop
  def fix
    auto_shop.fix_vehicle
  end
  
  private
    # Safety first! Puts on our seatbelt
    def put_on_seatbelt
      self.seatbelt_on = true
    end
    
    # We crashed! Increase the insurance premium on the vehicle
    def increase_insurance_premium
      self.insurance_premium += 100
    end
    
    # Is the auto shop currently servicing another customer?
    def auto_shop_busy?
      auto_shop.busy?
    end
end

class Car < Vehicle
  state_machine do
    event :reverse do
      transition :to => 'backing_up', :from => %w(parked idling first_gear)
    end
    
    event :park do
      transition :to => 'parked', :from => 'backing_up'
    end
    
    event :idle do
      transition :to => 'idling', :from => 'backing_up'
    end
    
    event :shift_up do
      transition :to => 'first_gear', :from => 'backing_up'
    end
  end
end

class Motorcycle < Vehicle
  state_machine :initial => 'idling'
end

class VehicleTest < Test::Unit::TestCase
  def setup
    @vehicle = Vehicle.new
  end
  
  def test_should_not_allow_access_to_subclass_events
    assert !@vehicle.respond_to?(:reverse)
  end
end

class VehicleUnsavedTest < Test::Unit::TestCase
  def setup
    @vehicle = Vehicle.new
  end
  
  def test_should_be_in_parked_state
    assert_equal 'parked', @vehicle.state
  end
  
  def test_should_not_be_able_to_park
    assert !@vehicle.can_park?
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_be_able_to_ignite
    assert @vehicle.can_ignite?
  end
  
  def test_should_allow_ignite
    assert @vehicle.ignite
    assert_equal 'idling', @vehicle.state
  end
  
  def test_should_be_saved_after_successful_event
    @vehicle.ignite
    assert !@vehicle.new_record?
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_not_allow_shift_up
    assert !@vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleParkedTest < Test::Unit::TestCase
  def setup
    @vehicle = Vehicle.new
  end
  
  def test_should_be_in_parked_state
    assert_equal 'parked', @vehicle.state
  end
  
  def test_should_not_have_the_seatbelt_on
    assert !@vehicle.seatbelt_on
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_allow_ignite
    assert @vehicle.ignite
    assert_equal 'idling', @vehicle.state
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_not_allow_shift_up
    assert !@vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
  
  def test_should_raise_exception_if_repair_not_allowed!
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@vehicle.repair!}
  end
end

class VehicleIdlingTest < Test::Unit::TestCase
  def setup
    @vehicle = Vehicle.new
    @vehicle.ignite
  end
  
  def test_should_be_in_idling_state
    assert_equal 'idling', @vehicle.state
  end
  
  def test_should_have_seatbelt_on
    assert @vehicle.seatbelt_on
  end
  
  def test_should_allow_park
    assert @vehicle.park
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_allow_shift_up
    assert @vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleFirstGearTest < Test::Unit::TestCase
  def setup
    @vehicle = Vehicle.new
    @vehicle.ignite
    @vehicle.shift_up
  end
  
  def test_should_be_in_first_gear_state
    assert_equal 'first_gear', @vehicle.state
  end
  
  def test_should_allow_park
    assert @vehicle.park
  end
  
  def test_should_allow_idle
    assert @vehicle.idle
  end
  
  def test_should_allow_shift_up
    assert @vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_allow_crash
    assert @vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleSecondGearTest < Test::Unit::TestCase
  def setup
    @vehicle = Vehicle.new
    @vehicle.ignite
    2.times {@vehicle.shift_up}
  end
  
  def test_should_be_in_second_gear_state
    assert_equal 'second_gear', @vehicle.state
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_allow_shift_up
    assert @vehicle.shift_up
  end
  
  def test_should_allow_shift_down
    assert @vehicle.shift_down
  end
  
  def test_should_allow_crash
    assert @vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleThirdGearTest < Test::Unit::TestCase
  def setup
    @vehicle = Vehicle.new
    @vehicle.ignite
    3.times {@vehicle.shift_up}
  end
  
  def test_should_be_in_third_gear_state
    assert_equal 'third_gear', @vehicle.state
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_not_allow_shift_up
    assert !@vehicle.shift_up
  end
  
  def test_should_allow_shift_down
    assert @vehicle.shift_down
  end
  
  def test_should_allow_crash
    assert @vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleStalledTest < Test::Unit::TestCase
  def setup
    @vehicle = Vehicle.new
    @vehicle.ignite
    @vehicle.shift_up
    @vehicle.crash
  end
  
  def test_should_be_in_stalled_state
    assert_equal 'stalled', @vehicle.state
  end
  
  def test_should_be_towed
    assert @vehicle.auto_shop.busy?
    assert_equal 1, @vehicle.auto_shop.num_customers
  end
  
  def test_should_have_an_increased_insurance_premium
    assert_equal 150, @vehicle.insurance_premium
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_allow_ignite
    assert @vehicle.ignite
  end
  
  def test_should_not_change_state_when_ignited
    assert_equal 'stalled', @vehicle.state
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_now_allow_shift_up
    assert !@vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@vehicle.crash
  end
  
  def test_should_allow_repair_if_auto_shop_is_busy
    assert @vehicle.repair
  end
  
  def test_should_not_allow_repair_if_auto_shop_is_available
    @vehicle.auto_shop.fix_vehicle
    assert !@vehicle.repair
  end
end

class VehicleRepairedTest < Test::Unit::TestCase
  def setup
    @vehicle = Vehicle.new
    @vehicle.ignite
    @vehicle.shift_up
    @vehicle.crash
    @vehicle.repair
  end
  
  def test_should_be_in_parked_state
    assert_equal 'parked', @vehicle.state
  end
  
  def test_should_not_have_a_busy_auto_shop
    assert @vehicle.auto_shop.available?
  end
end

class MotorcycleTest < Test::Unit::TestCase
  def setup
    @motorcycle = Motorcycle.new
  end
  
  def test_should_be_in_idling_state
    assert_equal 'idling', @motorcycle.state
  end
  
  def test_should_allow_park
    assert @motorcycle.park
  end
  
  def test_should_not_allow_ignite
    assert !@motorcycle.ignite
  end
  
  def test_should_allow_shift_up
    assert @motorcycle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@motorcycle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@motorcycle.crash
  end
  
  def test_should_not_allow_repair
    assert !@motorcycle.repair
  end
end

class CarTest < Test::Unit::TestCase
  def setup
    @car = Car.new
  end
  
  def test_should_be_in_parked_state
    assert_equal 'parked', @car.state
  end
  
  def test_should_not_have_the_seatbelt_on
    assert !@car.seatbelt_on
  end
  
  def test_should_not_allow_park
    assert !@car.park
  end
  
  def test_should_allow_ignite
    assert @car.ignite
    assert_equal 'idling', @car.state
  end
  
  def test_should_not_allow_idle
    assert !@car.idle
  end
  
  def test_should_not_allow_shift_up
    assert !@car.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@car.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@car.crash
  end
  
  def test_should_not_allow_repair
    assert !@car.repair
  end
  
  def test_should_allow_reverse
    assert @car.reverse
  end
end

class CarBackingUpTest < Test::Unit::TestCase
  def setup
    @car = Car.new
    @car.reverse
  end
  
  def test_should_be_in_backing_up_state
    assert_equal 'backing_up', @car.state
  end
  
  def test_should_allow_park
    assert @car.park
  end
  
  def test_should_not_allow_ignite
    assert !@car.ignite
  end
  
  def test_should_allow_idle
    assert @car.idle
  end
  
  def test_should_allow_shift_up
    assert @car.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@car.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@car.crash
  end
  
  def test_should_not_allow_repair
    assert !@car.repair
  end
  
  def test_should_not_allow_reverse
    assert !@car.reverse
  end
end

class AutoShopAvailableTest < Test::Unit::TestCase
  def setup
    @auto_shop = AutoShop.new
  end
  
  def test_should_be_in_available_state
    assert_equal 'available', @auto_shop.state
  end
  
  def test_should_allow_tow_vehicle
    assert @auto_shop.tow_vehicle
  end
  
  def test_should_not_allow_fix_vehicle
    assert !@auto_shop.fix_vehicle
  end
end

class AutoShopBusyTest < Test::Unit::TestCase
  def setup
    @auto_shop = AutoShop.new
    @auto_shop.tow_vehicle
  end
  
  def test_should_be_in_busy_state
    assert_equal 'busy', @auto_shop.state
  end
  
  def test_should_have_incremented_number_of_customers
    assert_equal 1, @auto_shop.num_customers
  end
  
  def test_should_not_allow_tow_vehicle
    assert !@auto_shop.tow_vehicle
  end
  
  def test_should_allow_fix_vehicle
    assert @auto_shop.fix_vehicle
  end
end
