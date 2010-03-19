class StateMachine::Railtie < Rails::Railtie
  railtie_name :state_machine
  
  rake_tasks do
    load 'tasks/state_machine.rb'
  end
end if defined?(Rails::Railtie)
