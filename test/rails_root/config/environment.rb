# Specifies gem version of Rails to use when vendor/rails is not present
#RAILS_GEM_VERSION = '1.1.6'

require File.join(File.dirname(__FILE__), 'boot')

module Rails
  class Initializer
    def load_plugins
      find_plugins(configuration.plugin_paths).each {|path| load_plugin(path)}
      $LOAD_PATH.uniq!
    end
  end
end

Rails::Initializer.run do |config|
  config.log_level = :debug
  config.cache_classes = false
  config.whiny_nils = true
  config.breakpoint_server = true
  config.load_paths << "#{File.dirname(__FILE__)}/../../../lib/"
  
  config.plugin_paths = [
    RAILS_ROOT + '/vendor/plugins/prerequisites',
    RAILS_ROOT + '/vendor/plugins'
  ]
end

Dependencies.log_activity = true