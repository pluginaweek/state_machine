namespace :state_machine do
  desc 'Draws a set of state machines using GraphViz. Target files to load with FILE=x,y,z; Machine class with CLASS=x,y,z; Font name with FONT=x; Image format with FORMAT=x; Orientation with ORIENTATION=x'
  task :draw do
    # Load the library
    $:.unshift(File.dirname(__FILE__) + '/lib')
    require 'state_machine'
    
    # Build drawing options
    options = {}
    options[:file] = ENV['FILE'] if ENV['FILE']
    options[:path] = ENV['TARGET'] if ENV['TARGET']
    options[:format] = ENV['FORMAT'] if ENV['FORMAT']
    options[:font] = ENV['FONT'] if ENV['FONT']
    options[:orientation] = ENV['ORIENTATION'] if ENV['ORIENTATION']
    
    StateMachine::Machine.draw(ENV['CLASS'], options)
  end
  
  namespace :draw do
    desc 'Draws a set of state machines using GraphViz for a Ruby on Rails application.  Target class with CLASS=x,y,z; Font name with FONT=x; Image format with FORMAT=x; Orientation with ORIENTATION=x'
    task :rails => [:environment, 'state_machine:draw']
    
    desc 'Draws a set of state machines using GraphViz for a Merb application.  Target class with CLASS=x,y,z; Font name with FONT=x; Image format with FORMAT=x; Orientation with ORIENTATION=x'
    task :merb => [:merb_env, 'state_machine:draw']
  end
end
