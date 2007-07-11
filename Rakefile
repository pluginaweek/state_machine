require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/contrib/sshpublisher'

PKG_NAME           = 'has_states'
PKG_VERSION        = '0.0.1'
PKG_FILE_NAME      = "#{PKG_NAME}-#{PKG_VERSION}"
RUBY_FORGE_PROJECT = 'pluginaweek'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the has_states plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/unit/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the has_states plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'HasStates'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

spec = Gem::Specification.new do |s|
  s.name            = PKG_NAME
  s.version         = PKG_VERSION
  s.platform        = Gem::Platform::RUBY
  s.summary         = ''
  
  s.files           = FileList['{app,db,lib,tasks,test}/**/*'].to_a + %w(init.rb MIT-LICENSE Rakefile README)
  s.require_path    = 'lib'
  s.autorequire     = 'has_states'
  s.has_rdoc        = true
  s.test_files      = Dir['test/unit/**/*_test.rb']
  
  s.author          = 'Aaron Pfeifer, Neil Abraham'
  s.email           = 'info@pluginaweek.org'
  s.homepage        = 'http://www.pluginaweek.org'
end
  
Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end

desc 'Publish the beta gem'
task :pgem => [:package] do
  Rake::SshFilePublisher.new('pluginaweek@pluginaweek.org', '/home/pluginaweek/gems.pluginaweek.org/gems', 'pkg', "#{PKG_FILE_NAME}.gem").upload
end

desc 'Publish the API documentation'
task :pdoc => [:rdoc] do
  Rake::SshDirPublisher.new('pluginaweek@pluginaweek.org', "/home/pluginaweek/api.pluginaweek.org/#{PKG_NAME}", 'rdoc').upload
end

desc 'Publish the API docs and gem'
task :publish => [:pdoc, :release]

desc 'Publish the release files to RubyForge.'
task :release => [:gem, :package] do
  require 'rubyforge'
  
  ruby_forge = RubyForge.new
  ruby_forge.login
  
  %w( gem tgz zip ).each do |ext|
    file = "pkg/#{PKG_FILE_NAME}.#{ext}"
    puts "Releasing #{File.basename(file)}..."
    
    ruby_forge.add_release(RUBY_FORGE_PROJECT, PKG_NAME, PKG_VERSION, file)
  end
end