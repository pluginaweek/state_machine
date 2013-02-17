$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'state_machine/version'

Gem::Specification.new do |s|
  s.name              = "state_machine"
  s.version           = StateMachine::VERSION
  s.authors           = ["Aaron Pfeifer"]
  s.email             = "aaron@pluginaweek.org"
  s.homepage          = "http://www.pluginaweek.org"
  s.description       = "Adds support for creating state machines for attributes on any Ruby class"
  s.summary           = "State machines for attributes"
  s.require_paths     = ["lib"]
  s.files             = Dir.glob("**/*").find_all{|f| File.file?(f)}
  s.test_files        = Dir.glob("test/**/*").find_all{|f| File.file?(f)}
  s.rdoc_options      = %w(--line-numbers --inline-source --title state_machine --main README.md)
  s.extra_rdoc_files  = %w(README.md CHANGELOG.md LICENSE)
  
  s.add_development_dependency("rake")
  s.add_development_dependency("simplecov")
  s.add_development_dependency("appraisal", "~> 0.4.0")
end
