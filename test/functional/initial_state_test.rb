require File.expand_path(File.dirname(__FILE__) + '/../test_helper')


@@state_machine_spec = Proc.new do
  state :builder do
    def build_stuff; end
  end
  state :attacker do
    def attack_dummy; end
  end
end


class RobotV1
  attr_accessor :mode

  state_machine(:mode, :initial => :builder, &@@state_machine_spec)

  def initialize(initial_mode=nil)
    self.mode = initial_mode.to_s unless initial_mode.nil?
    super()
  end
end


class RobotV2
  attr_accessor :mode

  state_machine(:mode, :initial => :builder, &@@state_machine_spec)

  def initialize(initial_mode=nil)
    @mode = initial_mode.to_s unless initial_mode.nil?
    super()
  end
end


class RobotV3
  attr_accessor :mode

  state_machine(:mode, :initial => lambda {|bot| bot.get_default_state}, &@@state_machine_spec)

  def initialize(initial_mode=nil)
    @default_state = 'builder'
    @mode = initial_mode.to_s unless initial_mode.nil?
    super()
  end

  def get_default_state
    @default_state
  end
end


class RobotV4
  attr_accessor :mode, :initial_mode

  state_machine(:mode, :initial => lambda {|bot| bot.get_initial_state}, &@@state_machine_spec)

  def initialize(initial_mode='builder')
    @initial_mode = initial_mode.to_s
    super()
  end

  def get_initial_state
    @initial_mode
  end
end


class RobotV5
  attr_accessor :mode

  state_machine(:mode, :initial => lambda { :builder }, &@@state_machine_spec)

  def initialize(initial_mode=nil)
    @mode = initial_mode.to_s unless initial_mode.nil?
    super()
  end
end


class InitialStateTest < Test::Unit::TestCase

  def initial_state_test(klass)
    bot = klass.new
    assert_equal 'builder', bot.mode
    assert_respond_to(bot, :build_stuff)
    assert_raise ::NoMethodError do
      bot.attack_dummy
    end

    bot = klass.new('builder')
    assert_equal 'builder', bot.mode
    assert_respond_to(bot, :build_stuff)
    assert_raise ::NoMethodError do
      bot.attack_dummy
    end

    bot = klass.new('attacker')
    assert_equal 'attacker', bot.mode
    assert_respond_to(bot, :attack_dummy)
    assert_raise ::NoMethodError do
      bot.build_stuff
    end
  end

  def test_should_initialize_state_with_setter_method
    initial_state_test RobotV1
  end

  def test_should_initialize_state_with_instance_var
    initial_state_test RobotV2
  end

  def test_should_initialize_state_with_lambda
    initial_state_test RobotV3
  end

  def test_should_initialize_state_with_lambda_and_unrelated_attribute
    initial_state_test RobotV4
  end

  def test_should_initialize_state_with_lambda_simple
    initial_state_test RobotV5
  end

end
