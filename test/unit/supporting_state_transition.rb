require File.dirname(__FILE__) + '/../test_helper'

class PluginAWeek::Has::States::StateTransition
  attr_reader :guards
  public :guard
end

class PluginAWeek::Has::States::StateTransitionTest < Test::Unit::TestCase
  def test_from_name
    transition = PluginAWeek::Has::States::StateTransition.new(:off, 'on', {})
    assert_equal 'off', transition.from_name
    
    transition = PluginAWeek::Has::States::StateTransition.new('off', 'on', {})
    assert_equal 'off', transition.from_name
  end
  
  def test_to_name
    transition = PluginAWeek::Has::States::StateTransition.new('off', :on, {})
    assert_equal 'on', transition.to_name
    
    transition = PluginAWeek::Has::States::StateTransition.new('off', 'on', {})
    assert_equal 'on', transition.to_name
  end
  
  def test_guards_as_object
    options = {:if => :return_true}
    transition = PluginAWeek::Has::States::StateTransition.new(:off, :on, options)
    
    assert_equal [:return_true], transition.guards
  end
  
  def test_guards_as_array
    options = {:if => [:return_true]}
    transition = PluginAWeek::Has::States::StateTransition.new(:off, :on, options)
    
    assert_equal [:return_true], transition.guards
  end
  
  def test_no_guards
    transition = PluginAWeek::Has::States::StateTransition.new(:off, :on, {})
    assert_equal [], transition.guards
  end
  
  def test_invalid_options
    options = {:invalid_key => true}
    assert_raise(ArgumentError) {PluginAWeek::Has::States::StateTransition.new(:off, :on, options)}
  end
  
  def test_guard_no_guards
    transition = PluginAWeek::Has::States::StateTransition.new(:off, :on, {})
    assert transition.guard(self)
  end
  
  def test_guard_should_be_true
    options = {:if => :return_true}
    transition = PluginAWeek::Has::States::StateTransition.new(:off, :on, options)
    
    assert transition.guard(self)
  end
  
  def test_guard_should_be_false
    options = {:if => [:return_true, :return_false]}
    transition = PluginAWeek::Has::States::StateTransition.new(:off, :on, options)
    
    assert !transition.guard(self)
  end
  
  def test_guard_with_parameters
    options = {:if => :return_param}
    transition = PluginAWeek::Has::States::StateTransition.new(:off, :on, options)
    
    assert transition.guard(self, true)
  end
  
  def test_equality
    transition = PluginAWeek::Has::States::StateTransition.new(:off, :on, {})
    same_transition = PluginAWeek::Has::States::StateTransition.new(:off, :on, {})
    different_transition = PluginAWeek::Has::States::StateTransition.new(:on, :off, {})
    
    assert transition == same_transition
    assert transition != different_transition
  end
  
  private
  def return_true
    true
  end
  
  def return_false
    false
  end
  
  def return_param(param)
    param
  end
end