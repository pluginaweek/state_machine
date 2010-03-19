namespace :state_machine do
  desc 'Draws a set of state machines using GraphViz. Target files to load with FILE=x,y,z; Machine class with CLASS=x,y,z; Font name with FONT=x; Image format with FORMAT=x; Orientation with ORIENTATION=x'
  task :draw do
    if defined?(Rails)
      Rake::Task['environment'].invoke
    elsif defined?(Merb)
      Rake::Task['merb_env'].invoke
      
      # Fix ruby-graphviz being incompatible with Merb's process title
      $0 = 'rake'
    else
      # Load the library
      $:.unshift(File.dirname(__FILE__) + '/..')
      require 'state_machine'
    end
    
    # Build drawing options
    options = {}
    options[:file] = ENV['FILE'] if ENV['FILE']
    options[:path] = ENV['TARGET'] if ENV['TARGET']
    options[:format] = ENV['FORMAT'] if ENV['FORMAT']
    options[:font] = ENV['FONT'] if ENV['FONT']
    options[:orientation] = ENV['ORIENTATION'] if ENV['ORIENTATION']
    
    StateMachine::Machine.draw(ENV['CLASS'], options)
  end
end
