require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class IntegrationMatcherTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
  end
  
  def test_should_return_nil_if_no_match_found
    assert_nil StateMachine::Integrations.match(@klass)
  end
  
  def test_should_return_integration_class_if_match_found
    integration = Module.new do
      def self.matches?(klass)
        true
      end
    end
    StateMachine::Integrations.const_set('Custom', integration)
    
    assert_equal integration, StateMachine::Integrations.match(@klass)
  ensure
    StateMachine::Integrations.send(:remove_const, 'Custom')
  end
end

class IntegrationFinderTest < Test::Unit::TestCase
  def test_should_find_active_record
    assert_equal StateMachine::Integrations::ActiveRecord, StateMachine::Integrations.find(:active_record)
  end
  
  def test_should_find_data_mapper
    assert_equal StateMachine::Integrations::DataMapper, StateMachine::Integrations.find(:data_mapper)
  end
  
  def test_should_find_sequel
    assert_equal StateMachine::Integrations::Sequel, StateMachine::Integrations.find(:sequel)
  end
  
  def test_should_raise_an_exception_if_invalid
    assert_raise(NameError) { StateMachine::Integrations.find(:invalid) }
  end
end
