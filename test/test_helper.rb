# Load the environment
ENV['RAILS_ENV'] ||= 'in_memory'
require File.dirname(__FILE__) + '/rails_root/config/environment.rb'

# Load the testing framework
require 'test_help'
silence_warnings { RAILS_ENV = ENV['RAILS_ENV'] }

# Run the plugin migrations
PluginAWeek::PluginMigrator.current_plugin = 'acts_as_state_machine'
PluginAWeek::PluginMigrator.migrate(File.dirname(__FILE__) + '/../db/migrate')

# Run the migrations
ActiveRecord::Migrator.migrate("#{RAILS_ROOT}/db/migrate")

# Setup the fixtures path
Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + '/fixtures/'
$LOAD_PATH.unshift(Test::Unit::TestCase.fixture_path)

class Test::Unit::TestCase #:nodoc:
  fixtures :states, :events
  
  def create_fixtures(*table_names)
    if block_given?
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names) { yield }
    else
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names)
    end
  end
  
  def self.require_fixture_classes(table_names=nil)
    # Don't allow fixture classes to be required because classes like Switch are
    # going to throw an error since the states and events have not yet been
    # loaded
  end
  
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
end