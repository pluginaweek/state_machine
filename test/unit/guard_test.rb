require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class GuardTest < Test::Unit::TestCase
  def setup
    @guard = StateMachine::Guard.new(:to => 'on', :from => 'off')
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) { StateMachine::Guard.new(:invalid => true) }
  end
  
  def test_should_have_requirements
    expected = {:to => %w(on), :from => %w(off)}
    assert_equal expected, @guard.requirements
  end
end

class GuardWithNoRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new
  end
  
  def test_should_match_nil_query
    assert @guard.matches?(@object, nil)
  end
  
  def test_should_match_empty_query
    assert @guard.matches?(@object, {})
  end
  
  def test_should_match_non_empty_query
    assert @guard.matches?(@object, :from => 'off', :to => 'on', :on => 'turn_on')
  end
end

class GuardWithToRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:to => 'on')
  end
  
  def test_should_match_if_not_specified
    assert @guard.matches?(@object, :from => 'off')
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :to => 'on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :to => 'off')
  end
  
  def test_should_not_match_if_nil
    assert !@guard.matches?(@object, :to => nil)
  end
  
  def test_should_ignore_from
    assert @guard.matches?(@object, :to => 'on', :from => 'off')
  end
  
  def test_should_ignore_on
    assert @guard.matches?(@object, :to => 'on', :on => 'turn_on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on), @guard.known_states
  end
end

class GuardWithMultipleToRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:to => %w(on off))
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :to => 'on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :to => 'maybe')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on off), @guard.known_states
  end
end

class GuardWithFromRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:from => 'on')
  end
  
  def test_should_match_if_not_specified
    assert @guard.matches?(@object, :to => 'off')
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :from => 'on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :from => 'off')
  end
  
  def test_should_not_match_if_nil
    assert !@guard.matches?(@object, :from => nil)
  end
  
  def test_should_ignore_to
    assert @guard.matches?(@object, :from => 'on', :to => 'off')
  end
  
  def test_should_ignore_on
    assert @guard.matches?(@object, :from => 'on', :on => 'turn_on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on), @guard.known_states
  end
end

class GuardWithMultipleFromRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:from => %w(on off))
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :from => 'on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :from => 'maybe')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on off), @guard.known_states
  end
end

class GuardWithOnRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:on => 'turn_on')
  end
  
  def test_should_match_if_not_specified
    assert @guard.matches?(@object, :from => 'off')
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :on => 'turn_on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :on => 'turn_off')
  end
  
  def test_should_not_match_if_nil
    assert !@guard.matches?(@object, :on => nil)
  end
  
  def test_should_ignore_to
    assert @guard.matches?(@object, :on => 'turn_on', :to => 'off')
  end
  
  def test_should_ignore_from
    assert @guard.matches?(@object, :on => 'turn_on', :from => 'off')
  end
  
  def test_should_not_be_included_in_known_states
    assert_equal [], @guard.known_states
  end
end

class GuardWithMultipleOnRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:on => %w(turn_on turn_off))
  end
  
  def test_should_match_if_included
    assert @guard.matches?(@object, :on => 'turn_on')
  end
  
  def test_should_not_match_if_not_included
    assert !@guard.matches?(@object, :on => 'turn_down')
  end
end

class GuardWithExceptToRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:except_to => 'off')
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :to => 'on')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :to => 'off')
  end
  
  def test_should_match_if_nil
    assert @guard.matches?(@object, :to => nil)
  end
  
  def test_should_ignore_from
    assert @guard.matches?(@object, :except_to => 'off', :from => 'off')
  end
  
  def test_should_ignore_on
    assert @guard.matches?(@object, :except_to => 'off', :on => 'turn_on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(off), @guard.known_states
  end
end

class GuardWithMultipleExceptToRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:except_to => %w(on off))
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :to => 'maybe')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :to => 'on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on off), @guard.known_states
  end
end

class GuardWithExceptFromRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:except_from => 'off')
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :from => 'on')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :from => 'off')
  end
  
  def test_should_match_if_nil
    assert @guard.matches?(@object, :from => nil)
  end
  
  def test_should_ignore_to
    assert @guard.matches?(@object, :from => 'on', :to => 'off')
  end
  
  def test_should_ignore_on
    assert @guard.matches?(@object, :from => 'on', :on => 'turn_on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(off), @guard.known_states
  end
end

class GuardWithMultipleExceptFromRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:except_from => %w(on off))
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :from => 'maybe')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :from => 'on')
  end
  
  def test_should_be_included_in_known_states
    assert_equal %w(on off), @guard.known_states
  end
end

class GuardWithExceptOnRequirementTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:except_on => 'turn_off')
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :on => 'turn_on')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :on => 'turn_off')
  end
  
  def test_should_match_if_nil
    assert @guard.matches?(@object, :on => nil)
  end
  
  def test_should_ignore_to
    assert @guard.matches?(@object, :on => 'turn_on', :to => 'off')
  end
  
  def test_should_ignore_from
    assert @guard.matches?(@object, :on => 'turn_on', :from => 'off')
  end
  
  def test_should_not_be_included_in_known_states
    assert_equal [], @guard.known_states
  end
end

class GuardWithMultipleExceptOnRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:except_on => %w(turn_on turn_off))
  end
  
  def test_should_match_if_not_included
    assert @guard.matches?(@object, :on => 'turn_down')
  end
  
  def test_should_not_match_if_included
    assert !@guard.matches?(@object, :on => 'turn_on')
  end
end

class GuardWithConflictingToRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:to => 'on', :except_to => 'on')
  end
  
  def test_should_ignore_except_requirement
    assert @guard.matches?(@object, :to => 'on')
  end
end

class GuardWithConflictingFromRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:from => 'on', :except_from => 'on')
  end
  
  def test_should_ignore_except_requirement
    assert @guard.matches?(@object, :from => 'on')
  end
end

class GuardWithConflictingOnRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:on => 'turn_on', :except_on => 'turn_on')
  end
  
  def test_should_ignore_except_requirement
    assert @guard.matches?(@object, :on => 'turn_on')
  end
end

class GuardWithDifferentRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:from => 'off', :to => 'on', :on => 'turn_on')
  end
  
  def test_should_match_empty_query
    assert @guard.matches?(@object)
  end
  
  def test_should_match_if_all_requirements_match
    assert @guard.matches?(@object, :from => 'off', :to => 'on', :on => 'turn_on')
  end
  
  def test_should_not_match_if_from_not_included
    assert !@guard.matches?(@object, :from => 'on')
  end
  
  def test_should_not_match_if_to_not_included
    assert !@guard.matches?(@object, :to => 'off')
  end
  
  def test_should_not_match_if_on_not_included
    assert !@guard.matches?(@object, :on => 'turn_off')
  end
  
  def test_should_include_all_known_states
    assert_equal %w(off on), @guard.known_states.sort
  end
  
  def test_should_not_duplicate_known_statse
    guard = StateMachine::Guard.new(:except_from => 'on', :to => 'on', :on => 'turn_on')
    assert_equal %w(on), guard.known_states
  end
end

class GuardWithNilRequirementsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @guard = StateMachine::Guard.new(:from => nil, :to => nil)
  end
  
  def test_should_match_empty_query
    assert @guard.matches?(@object)
  end
  
  def test_should_match_if_all_requirements_match
    assert @guard.matches?(@object, :from => nil, :to => nil)
  end
  
  def test_should_not_match_if_from_not_included
    assert !@guard.matches?(@object, :from => 'off')
  end
  
  def test_should_not_match_if_to_not_included
    assert !@guard.matches?(@object, :to => 'on')
  end
  
  def test_should_include_all_known_states
    assert_equal [nil], @guard.known_states
  end
end

class GuardWithIfConditionalTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_match_if_true
    guard = StateMachine::Guard.new(:if => lambda {true})
    assert guard.matches?(@object)
  end
  
  def test_should_not_match_if_false
    guard = StateMachine::Guard.new(:if => lambda {false})
    assert !guard.matches?(@object)
  end
end

class GuardWithUnlessConditionalTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_match_if_false
    guard = StateMachine::Guard.new(:unless => lambda {false})
    assert guard.matches?(@object)
  end
  
  def test_should_not_match_if_true
    guard = StateMachine::Guard.new(:unless => lambda {true})
    assert !guard.matches?(@object)
  end
end

class GuardWithConflictingConditionalsTest < Test::Unit::TestCase
  def setup
    @object = Object.new
  end
  
  def test_should_match_if_true
    guard = StateMachine::Guard.new(:if => lambda {true}, :unless => lambda {true})
    assert guard.matches?(@object)
  end
  
  def test_should_not_match_if_false
    guard = StateMachine::Guard.new(:if => lambda {false}, :unless => lambda {false})
    assert !guard.matches?(@object)
  end
end

begin
  # Load library
  require 'rubygems'
  require 'graphviz'
  
  class GuardDrawingTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      states = %w(parked idling)
      
      graph = GraphViz.new('G')
      states.each {|state| graph.add_node(state)}
      
      @guard = StateMachine::Guard.new(:from => 'idling', :to => 'parked')
      @edges = @guard.draw(graph, 'park', states)
    end
    
    def test_should_create_edges
      assert_equal 1, @edges.size
    end
    
    def test_should_use_from_state_from_start_node
      assert_equal 'idling', @edges.first.instance_variable_get('@xNodeOne')
    end
    
    def test_should_use_to_state_for_end_node
      assert_equal 'parked', @edges.first.instance_variable_get('@xNodeTwo')
    end
    
    def test_should_use_event_name_as_label
      assert_equal 'park', @edges.first['label']
    end
  end
  
  class GuardDrawingWithFromRequirementTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      states = %w(parked idling first_gear)
      
      graph = GraphViz.new('G')
      states.each {|state| graph.add_node(state)}
      
      @guard = StateMachine::Guard.new(:from => %w(idling first_gear), :to => 'parked')
      @edges = @guard.draw(graph, 'park', states)
    end
    
    def test_should_generate_edges_for_each_valid_from_state
      %w(idling first_gear).each_with_index do |from_state, index|
        edge = @edges[index]
        assert_equal from_state, edge.instance_variable_get('@xNodeOne')
        assert_equal 'parked', edge.instance_variable_get('@xNodeTwo')
      end
    end
  end
  
  class GuardDrawingWithExceptFromRequirementTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      states = %w(parked idling first_gear)
      
      graph = GraphViz.new('G')
      states.each {|state| graph.add_node(state)}
      
      @guard = StateMachine::Guard.new(:except_from => 'parked', :to => 'parked')
      @edges = @guard.draw(graph, 'park', states)
    end
    
    def test_should_generate_edges_for_each_valid_from_state
      %w(idling first_gear).each_with_index do |from_state, index|
        edge = @edges[index]
        assert_equal from_state, edge.instance_variable_get('@xNodeOne')
        assert_equal 'parked', edge.instance_variable_get('@xNodeTwo')
      end
    end
  end
  
  class GuardDrawingWithoutFromRequirementTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      states = %w(parked idling first_gear)
      
      graph = GraphViz.new('G')
      states.each {|state| graph.add_node(state)}
      
      @guard = StateMachine::Guard.new(:to => 'parked')
      @edges = @guard.draw(graph, 'park', states)
    end
    
    def test_should_generate_edges_for_each_valid_from_state
      %w(parked idling first_gear).each_with_index do |from_state, index|
        edge = @edges[index]
        assert_equal from_state, edge.instance_variable_get('@xNodeOne')
        assert_equal 'parked', edge.instance_variable_get('@xNodeTwo')
      end
    end
  end
  
  class GuardDrawingWithoutToRequirementTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      
      graph = GraphViz.new('G')
      graph.add_node('parked')
      
      @guard = StateMachine::Guard.new(:from => 'parked')
      @edges = @guard.draw(graph, 'park', ['parked'])
    end
    
    def test_should_create_loopback_edge
      assert_equal 'parked', @edges.first.instance_variable_get('@xNodeOne')
      assert_equal 'parked', @edges.first.instance_variable_get('@xNodeTwo')
    end
  end
  
  class GuardWithProcStatesTest < Test::Unit::TestCase
    def setup
      @machine = StateMachine::Machine.new(Class.new)
      @from_state = lambda {}
      @to_state = lambda {}
      states = [@from_state, @to_state]
      
      graph = GraphViz.new('G')
      states.each {|state| graph.add_node("lambda#{state.object_id.abs}")}
      
      @guard = StateMachine::Guard.new(:from => @from_state, :to => @to_state)
      @edges = @guard.draw(graph, 'park', states)
    end
    
    def test_should_use_state_id_for_from_state
      assert_equal "lambda#{@from_state.object_id.abs}", @edges.first.instance_variable_get('@xNodeOne')
    end
    
    def test_should_use_state_id_for_to_state
      assert_equal "lambda#{@to_state.object_id.abs}", @edges.first.instance_variable_get('@xNodeTwo')
    end
  end
rescue LoadError
  $stderr.puts 'Skipping GraphViz StateMachine::Guard tests. `gem install ruby-graphviz` and try again.'
end
