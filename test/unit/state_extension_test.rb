require File.dirname(__FILE__) + '/../test_helper'

class StateExtensionTest < Test::Unit::TestCase
  fixtures :highways, :vehicles
  
  def setup
    @highway = highways(:route_66)
  end
  
  def test_should_find_first_record_in_association_with_given_state
    assert_equal vehicles(:first_gear), @highway.vehicles.find_in_states(:first, :first_gear)
  end
  
  def test_should_find_first_record_in_association_with_any_of_multiple_states
    assert_equal vehicles(:parked), @highway.vehicles.find_in_states(:first, :second_gear, :third_gear, :parked)
  end
  
  def test_should_find_all_records_in_association_with_given_state
    assert_equal [vehicles(:first_gear), vehicles(:first_gear_2)], @highway.vehicles.find_in_states(:all, :first_gear)
  end
  
  def test_should_find_all_records_in_association_with_any_of_multiple_states
    assert_equal [vehicles(:parked)], @highway.vehicles.find_in_states(:all, :second_gear, :third_gear, :parked)
  end
  
  def test_should_find_all_records_in_association_with_additional_options
    assert_equal [vehicles(:first_gear)], @highway.vehicles.find_in_states(:all, :first_gear, :conditions => 'vehicles.id = 3')
  end
  
  def test_should_create_state_finders_for_each_active_state
    Vehicle.active_states.keys.each do |state_name|
      assert @highway.vehicles.respond_to?(state_name)
    end
  end
  
  def test_state_finder_should_be_empty_if_no_records_in_state
    assert_equal [], @highway.vehicles.second_gear
  end
  
  def test_state_finder_should_find_all_if_records_in_state
    assert_equal [vehicles(:first_gear), vehicles(:first_gear_2)], @highway.vehicles.first_gear
  end
  
  def test_state_finder_should_allow_cardinality_specifier
    assert_equal vehicles(:parked), @highway.vehicles.parked(:first)
  end
  
  def test_state_finder_should_allow_additional_options
    assert_equal [vehicles(:first_gear)], @highway.vehicles.first_gear(:conditions => 'vehicles.id = 3')
  end
  
  def test_should_create_state_counters_for_each_active_state
    Vehicle.active_states.keys.each do |state_name|
      assert @highway.vehicles.respond_to?("#{state_name}_count")
    end
  end
  
  def test_state_counter_with_no_records
    assert_equal 0, @highway.vehicles.second_gear_count
  end
  
  def test_state_counter_with_one_record
    assert_equal 1, @highway.vehicles.idling_count
  end
  
  def test_state_counter_with_multiple_records
    assert_equal 2, @highway.vehicles.first_gear_count
  end
end