require File.dirname(__FILE__) + '/../test_helper'

class ActiveStateTest < Test::Unit::TestCase
  module StateExtension
  end
  
  cattr_accessor :record_state_changes
  
  def setup
    @@record_state_changes = true
    
    state = State.new(:name => 'on')
    state.id = 999
    @state = PluginAWeek::Has::States::ActiveState.new(self.class, state)
  end
  
  def test_should_raise_exception_if_invalid_option_used_on_create
    assert_raise(ArgumentError) {PluginAWeek::Has::States::ActiveState.new(self.class, State.new, :invalid_option => true)}
  end
  
  def test_should_set_owner_class_to_initialized_class
    assert_equal self.class, @state.owner_class
  end
  
  def test_should_allow_owner_class_to_be_modified
    @state.owner_class = State
    assert_equal State, @state.owner_class
  end
  
  def test_should_not_cache_owner_class
    owner_class = @state.owner_class
    @state.owner_class = State
    assert_not_equal owner_class, @state.owner_class
    assert_equal State, @state.owner_class
  end
  
  def test_should_create_predicate_methods
    assert self.class.instance_methods.include?('on?')
  end
  
  def test_should_create_state_change_accessor_for_each_state_if_recording_changes
    assert self.class.instance_methods.include?('on_at')
  end
  
  def test_should_not_create_state_change_accessor_for_each_state_if_not_recording_changes
    @@record_state_changes = false
    
    state = State.new(:name => 'off')
    state.id = 998
    PluginAWeek::Has::States::ActiveState.new(self.class, state)
    
    assert !self.class.instance_methods.include?('off_at')
  end
  
  def test_should_create_callbacks
    [:before_enter, :after_enter, :before_exit, :after_exit].each do |callback|
      assert self.class.singleton_methods.include?("#{callback}_on")
    end
  end
  
  def test_should_create_state_finders_for_each_active_state
    assert StateExtension.instance_methods.include?('on')
  end
  
  def test_should_create_state_counters_for_each_active_state
    assert StateExtension.instance_methods.include?('on_count')
  end
end