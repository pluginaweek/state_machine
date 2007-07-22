# Load local repository plugin paths
$:.unshift("#{RAILS_ROOT}/../../../../associations/class_associations/lib")
$:.unshift("#{RAILS_ROOT}/../../../../miscellaneous/dry_transaction_rollbacks/lib")
$:.unshift("#{RAILS_ROOT}/../../../../../ruby/object/eval_call/lib")

# Load the plugin testing framework
$:.unshift("#{File.dirname(__FILE__)}/../../../../test/plugin_test_helper/lib")
require 'rubygems'
require 'plugin_test_helper'

PluginAWeek::PluginMigrations.migrate('has_states')

# Run the migrations
ActiveRecord::Migrator.migrate("#{RAILS_ROOT}/db/migrate")

class Test::Unit::TestCase #:nodoc:
  fixtures :states, :events
  
  def self.require_fixture_classes(table_names=nil)
    # Don't allow fixture classes to be required because classes like Switch are
    # going to throw an error since the states and events have not yet been
    # loaded
  end
end