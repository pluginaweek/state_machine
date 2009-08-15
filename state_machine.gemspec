# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{state_machine}
  s.version = "0.8.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Aaron Pfeifer"]
  s.date = %q{2009-08-15}
  s.description = %q{Adds support for creating state machines for attributes on any Ruby class}
  s.email = %q{aaron@pluginaweek.org}
  s.files = ["examples/Car_state.png", "examples/AutoShop_state.png", "examples/rails-rest", "examples/rails-rest/view_show.html.erb", "examples/rails-rest/controller.rb", "examples/rails-rest/model.rb", "examples/rails-rest/view_index.html.erb", "examples/rails-rest/view_new.html.erb", "examples/rails-rest/view_edit.html.erb", "examples/rails-rest/migration.rb", "examples/merb-rest", "examples/merb-rest/view_show.html.erb", "examples/merb-rest/controller.rb", "examples/merb-rest/model.rb", "examples/merb-rest/view_index.html.erb", "examples/merb-rest/view_new.html.erb", "examples/merb-rest/view_edit.html.erb", "examples/vehicle.rb", "examples/TrafficLight_state.png", "examples/auto_shop.rb", "examples/traffic_light.rb", "examples/Vehicle_state.png", "examples/car.rb", "lib/state_machine.rb", "lib/state_machine", "lib/state_machine/condition_proxy.rb", "lib/state_machine/machine_collection.rb", "lib/state_machine/machine.rb", "lib/state_machine/event_collection.rb", "lib/state_machine/integrations", "lib/state_machine/integrations/active_record", "lib/state_machine/integrations/active_record/locale.rb", "lib/state_machine/integrations/active_record/observer.rb", "lib/state_machine/integrations/data_mapper.rb", "lib/state_machine/integrations/sequel.rb", "lib/state_machine/integrations/active_record.rb", "lib/state_machine/integrations/data_mapper", "lib/state_machine/integrations/data_mapper/observer.rb", "lib/state_machine/matcher_helpers.rb", "lib/state_machine/assertions.rb", "lib/state_machine/matcher.rb", "lib/state_machine/eval_helpers.rb", "lib/state_machine/guard.rb", "lib/state_machine/integrations.rb", "lib/state_machine/callback.rb", "lib/state_machine/event.rb", "lib/state_machine/extensions.rb", "lib/state_machine/state.rb", "lib/state_machine/transition.rb", "lib/state_machine/node_collection.rb", "lib/state_machine/state_collection.rb", "tasks/state_machine.rb", "tasks/state_machine.rake", "test/unit", "test/unit/assertions_test.rb", "test/unit/integrations_test.rb", "test/unit/node_collection_test.rb", "test/unit/invalid_event_test.rb", "test/unit/event_test.rb", "test/unit/state_collection_test.rb", "test/unit/callback_test.rb", "test/unit/condition_proxy_test.rb", "test/unit/integrations", "test/unit/integrations/sequel_test.rb", "test/unit/integrations/data_mapper_test.rb", "test/unit/integrations/active_record_test.rb", "test/unit/eval_helpers_test.rb", "test/unit/guard_test.rb", "test/unit/state_test.rb", "test/unit/transition_test.rb", "test/unit/matcher_test.rb", "test/unit/invalid_transition_test.rb", "test/unit/machine_test.rb", "test/unit/machine_collection_test.rb", "test/unit/state_machine_test.rb", "test/unit/event_collection_test.rb", "test/unit/matcher_helpers_test.rb", "test/test_helper.rb", "test/classes", "test/classes/switch.rb", "test/functional", "test/functional/state_machine_test.rb", "CHANGELOG.rdoc", "init.rb", "LICENSE", "Rakefile", "README.rdoc"]
  s.has_rdoc = true
  s.homepage = %q{http://www.pluginaweek.org}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{pluginaweek}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Adds support for creating state machines for attributes on any Ruby class}
  s.test_files = ["test/unit/assertions_test.rb", "test/unit/integrations_test.rb", "test/unit/node_collection_test.rb", "test/unit/invalid_event_test.rb", "test/unit/event_test.rb", "test/unit/state_collection_test.rb", "test/unit/callback_test.rb", "test/unit/condition_proxy_test.rb", "test/unit/integrations/sequel_test.rb", "test/unit/integrations/data_mapper_test.rb", "test/unit/integrations/active_record_test.rb", "test/unit/eval_helpers_test.rb", "test/unit/guard_test.rb", "test/unit/state_test.rb", "test/unit/transition_test.rb", "test/unit/matcher_test.rb", "test/unit/invalid_transition_test.rb", "test/unit/machine_test.rb", "test/unit/machine_collection_test.rb", "test/unit/state_machine_test.rb", "test/unit/event_collection_test.rb", "test/unit/matcher_helpers_test.rb", "test/functional/state_machine_test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
