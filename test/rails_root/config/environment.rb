require File.join(File.dirname(__FILE__), 'boot')

# set_load_path
load_paths = %w(app app/models config vendor).collect {|dir| "#{APP_ROOT}/#{dir}"}
load_paths.reverse_each {|dir| $LOAD_PATH.unshift("#{APP_ROOT}/#{dir}") if File.directory?(dir)}
$LOAD_PATH.uniq!

# set_autoload_paths
Dependencies.load_paths = load_paths

# load_environment
APP_ENV = ENV['DB']

# initialize_database
ActiveRecord::Base.configurations = YAML::load(IO.read("#{APP_ROOT}/config/database.yml"))
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[APP_ENV])

# initializer_logger
log_path = "#{APP_ROOT}/log/#{APP_ENV}.log"
begin
  logger = Logger.new(log_path)
  logger.level = Logger::DEBUG
rescue StandardError
  logger = Logger.new(STDERR)
  logger.level = Logger::WARN
  logger.warn(
    "Logger Error: Unable to access log file. Please ensure that #{log_path} exists and is chmod 0666. " +
    "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
  )
end

# initialize_framework_logging
ActiveRecord::Base.logger = logger

# initialize_dependency_mechanism
Dependencies.mechanism = :require

# initialize_breakpoints
require 'active_support/breakpoint'

# initialize_whiny_nils
# require('active_support/whiny_nil')

# load_observers
ActiveRecord::Base.instantiate_observers