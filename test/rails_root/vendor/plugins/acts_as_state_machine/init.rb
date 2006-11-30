init_path = "#{RAILS_ROOT}/../../init.rb"
silence_warnings { eval(IO.read(init_path), binding, init_path) }

# Add the plugin load paths since they're not in our proxy
class << self
  def after_initialize_with_plugin_paths
    add_plugin_load_paths("#{RAILS_ROOT}/../..")
    after_initialize_without_plugin_paths
  end
  alias_method_chain :after_initialize, :plugin_paths
end