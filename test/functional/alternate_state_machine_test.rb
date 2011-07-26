require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AlternateAutoShop
  attr_accessor :num_customers
  attr_accessor :weekend
  attr_accessor :have_parts

  def initialize
    @num_customers = 0
    @weekend = false
    @have_parts = true
    super
  end

  state_machine :initial => :available, :syntax => :alternate do
    after_transition :available => any, :do => :increment_customers
    after_transition :busy => any, :do => :decrement_customers

    state :available do
      event :tow_vehicle, :to => :busy, :unless => :weekend?
    end

    state :busy do
      event :fix_vehicle, :to => :available, :if => :have_parts?
    end
  end

  def weekend?
    !!weekend
  end

  def have_parts?
    !!have_parts
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

class AlternateAutoShopAvailableTest < Test::Unit::TestCase
  def setup
    @auto_shop = AlternateAutoShop.new
  end

  def test_should_be_in_available_state
    assert_equal 'available', @auto_shop.state
  end

  def test_should_allow_tow_vehicle
    assert @auto_shop.tow_vehicle
  end

  def test_should_allow_tow_vehicle_on_weekends
    @auto_shop.weekend = true
    assert !@auto_shop.tow_vehicle
  end

  def test_should_not_allow_fix_vehicle
    assert !@auto_shop.fix_vehicle
  end

  def test_should_append_to_machine
    AlternateAutoShop.class_eval do
      state_machine :initial => :available, :syntax => :alternate do
        state any do
          event :close, :to => :closed
        end
      end
    end

    assert @auto_shop.close
    assert @auto_shop.closed?
  end

  def test_should_not_allow_event_outside_state
    assert_raises(StateMachine::AlternateMachine::InvalidEventError) do
      AlternateAutoShop.class_eval do
        state_machine :initial => :available, :syntax => :alternate do
          state any do
          end

          event :not_work, :to => :never
        end
      end
    end
  end
end

class AlternateAutoShopBusyTest < Test::Unit::TestCase
  def setup
    @auto_shop = AlternateAutoShop.new
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

  def test_should_not_allow_fix_vehicle_if_dont_have_parts
    @auto_shop.have_parts = false
    assert !@auto_shop.fix_vehicle
  end
end