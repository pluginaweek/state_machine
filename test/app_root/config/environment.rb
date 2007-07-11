require 'config/boot'

$:.unshift("#{RAILS_ROOT}/../../../plugin_dependencies/lib")
begin
  require 'plugin_dependencies'
rescue
end

Rails::Initializer.run do |config|
  config.log_level = :debug
  config.cache_classes = false
  config.whiny_nils = true
  config.breakpoint_server = true
  config.load_paths << "#{RAILS_ROOT}/../../lib"
  
  config.plugin_paths.concat([
    "#{RAILS_ROOT}/../../..",
    "#{RAILS_ROOT}/../../../../associations",
    "#{RAILS_ROOT}/../../../../migrations",
    "#{RAILS_ROOT}/../../../../miscellaneous",
    "#{RAILS_ROOT}/../../../../../rails",
    "#{RAILS_ROOT}/../../../../../ruby/object",
    "#{RAILS_ROOT}/../../../../../test",
  ])
  config.plugins = [
    File.basename(File.expand_path("#{RAILS_ROOT}/../..")),
    'appable_plugins',
    'plugin_migrations',
    'class_associations',
    'dry_transaction_rollbacks',
    'eval_call',
    'dry_validity_assertions'
  ]
end

Dependencies.log_activity = true