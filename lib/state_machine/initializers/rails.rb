class StateMachine::Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/state_machine.rb'
  end
end if defined?(Rails::Railtie)
