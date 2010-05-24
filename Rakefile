require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name              = 'state_machine'
  s.version           = '0.9.2'
  s.platform          = Gem::Platform::RUBY
  s.summary           = 'Adds support for creating state machines for attributes on any Ruby class'
  s.description       = s.summary
  
  s.files             = FileList['{examples,lib,test}/**/*'] + %w(CHANGELOG.rdoc init.rb LICENSE Rakefile README.rdoc) - FileList['test/*.log']
  s.require_path      = 'lib'
  s.has_rdoc          = true
  s.test_files        = Dir['test/**/*_test.rb']
  
  s.author            = 'Aaron Pfeifer'
  s.email             = 'aaron@pluginaweek.org'
  s.homepage          = 'http://www.pluginaweek.org'
  s.rubyforge_project = 'pluginaweek'
end

desc 'Default: run all tests.'
task :default => :test

desc "Test the #{spec.name} plugin."
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.test_files = ENV['INTEGRATION'] ? Dir["test/unit/integrations/#{ENV['INTEGRATION']}_test.rb"] : Dir['test/{functional,unit}/*_test.rb']
  t.verbose = true
end

begin
  require 'rcov/rcovtask'
  namespace :test do
    desc "Test the #{spec.name} plugin with Rcov."
    Rcov::RcovTask.new(:rcov) do |t|
      t.libs << 'lib'
      t.test_files = spec.test_files
      t.rcov_opts << '--exclude="^(?!lib/)"'
      t.verbose = true
    end
  end
rescue LoadError
end

desc "Generate documentation for the #{spec.name} plugin."
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = spec.name
  rdoc.template = '../rdoc_template.rb'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc', 'CHANGELOG.rdoc', 'LICENSE', 'lib/**/*.rb')
end

desc 'Generate a gemspec file.'
task :gemspec do
  File.open("#{spec.name}.gemspec", 'w') do |f|
    f.write spec.to_ruby
  end
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc 'Publish the release files to RubyForge.'
task :release => :package do
  require 'rake/gemcutter'
  
  Rake::Gemcutter::Tasks.new(spec)
  Rake::Task['gem:push'].invoke
end

load File.dirname(__FILE__) + '/lib/tasks/state_machine.rake'
