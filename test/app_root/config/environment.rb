require 'config/boot'

$:.unshift("#{RAILS_ROOT}/../../../../../rails/plugin_dependencies/lib")
begin
  require 'plugin_dependencies'
rescue Exception => e
end

Rails::Initializer.run do |config|
  config.plugin_paths.concat([
    "#{RAILS_ROOT}/../../..",
    "#{RAILS_ROOT}/../../../../migrations",
    "#{RAILS_ROOT}/../../../../../rails",
    "#{RAILS_ROOT}/../../../../../test"
  ])
  config.plugins = [
    'loaded_plugins',
    'appable_plugins',
    'plugin_migrations',
    File.basename(File.expand_path("#{RAILS_ROOT}/../..")),
    'dry_validity_assertions'
  ]
  config.cache_classes = false
  config.whiny_nils = true
end

Dependencies.log_activity = true
