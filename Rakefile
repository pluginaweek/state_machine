require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run all tests.'
task :default => :test

desc "Test state_machine."
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.test_files = ENV['INTEGRATION'] ? Dir["test/unit/integrations/#{ENV['INTEGRATION']}_test.rb"] : Dir['test/{functional,unit}/*_test.rb'] + ['test/unit/integrations/base_test.rb']
  t.verbose = true
end

begin
  require 'rcov/rcovtask'
  namespace :test do
    desc "Test state_machine with Rcov."
    Rcov::RcovTask.new(:rcov) do |t|
      t.libs << 'lib'
      t.test_files = Dir['test/**/*_test.rb']
      t.rcov_opts << '--exclude="^(?!lib/)"'
      t.verbose = true
    end
  end
rescue LoadError
end

desc "Generate documentation for state_machine."
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'state_machine'
  rdoc.options << '--line-numbers' << '--inline-source' << '--main=README.rdoc'
  rdoc.rdoc_files.include('README.rdoc', 'CHANGELOG.rdoc', 'LICENSE', 'lib/**/*.rb')
end

load File.dirname(__FILE__) + '/lib/tasks/state_machine.rake'
