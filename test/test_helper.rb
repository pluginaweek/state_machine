$:.unshift("#{File.dirname(__FILE__)}/../../../../test/plugin_test_helper/lib")
require 'rubygems'
require 'plugin_test_helper'
require 'dry_validity_assertions'

# Run the plugin migrations
PluginAWeek::PluginMigrations.migrate('acts_as_state_machine')

# Run the migrations
ActiveRecord::Migrator.migrate("#{RAILS_ROOT}/db/migrate")

class Test::Unit::TestCase #:nodoc:
  fixtures :states, :events
  
  def self.require_fixture_classes(table_names=nil)
    # Don't allow fixture classes to be required because classes like Switch are
    # going to throw an error since the states and events have not yet been
    # loaded
  end
  
#  self.use_transactional_fixtures = true
#  self.use_instantiated_fixtures  = false
end