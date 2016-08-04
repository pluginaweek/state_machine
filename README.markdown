# state_machine ![CI](https://secure.travis-ci.org/pluginaweek/state_machine.png "CI") #

**state_machine** adds support for creating state machines for attributes on any
Ruby class.

## Resources ##

API

* [http://rdoc.info/github/pluginaweek/state_machine/master/frames](http://rdoc.info/github/pluginaweek/state_machine/master/frames)

Bugs

* [http://github.com/pluginaweek/state_machine/issues](http://github.com/pluginaweek/state_machine/issues)

Development

* [http://github.com/pluginaweek/state_machine](http://github.com/pluginaweek/state_machine)

Testing

* [http://travis-ci.org/pluginaweek/state_machine](http://travis-ci.org/pluginaweek/state_machine)

Source

* git://github.com/pluginaweek/state_machine.git

Mailing List

* [http://groups.google.com/group/pluginaweek-talk](http://groups.google.com/group/pluginaweek-talk)

## Description ##

State machines make it dead-simple to manage the behavior of a class. Too often,
the state of an object is kept by creating multiple boolean attributes and
deciding how to behave based on the values.  This can become cumbersome and
difficult to maintain when the complexity of your class starts to increase.

*state_machine* simplifies this design by introducing the various parts of a real
state machine, including states, events, transitions, and callbacks.  However,
the api is designed to be so simple you don't even need to know what a
state machine is :)

Some brief, high-level features include:

* Defining state machines on any Ruby class
* Multiple state machines on a single class
* Namespaced state machines
* before/after/around/failure transition hooks with explicit transition requirements
* Integration with ActiveModel, ActiveRecord, DataMapper, Mongoid, MongoMapper, and Sequel
* State predicates
* State-driven instance / class behavior
* State values of any data type
* Dynamically-generated state values
* Event parallelization
* Attribute-based event transitions
* Path analysis
* Inheritance
* Internationalization
* GraphViz visualization creator
* Flexible machine syntax

Examples of the usage patterns for some of the above features are shown below.
You can find much more detailed documentation in the actual API.

## Usage ##

### Example ###

Below is an example of many of the features offered by this plugin, including:

* Initial states
* Namespaced states
* Transition callbacks
* Conditional transitions
* State-driven instance behavior
* Customized state values
* Parallel events
* Path analysis

Class definition:

```ruby
class Vehicle
  attr_accessor :seatbelt_on, :time_used

  state_machine :state, :initial => :parked do
    before_transition :parked => any - :parked, :do => :put_on_seatbelt

    after_transition :on => :crash, :do => :tow
    after_transition :on => :repair, :do => :fix
    after_transition any => :parked do |vehicle, transition|
      vehicle.seatbelt_on = false
    end

    after_failure :on => :ignite, :do => :log_start_failure

    around_transition do |vehicle, transition, block|
      start = Time.now
      block.call
      vehicle.time_used += Time.now - start
    end

    event :park do
      transition [:idling, :first_gear] => :parked
    end

    event :ignite do
      transition :stalled => same, :parked => :idling
    end

    event :idle do
      transition :first_gear => :idling
    end

    event :shift_up do
      transition :idling => :first_gear, :first_gear => :second_gear, :second_gear => :third_gear
    end

    event :shift_down do
      transition :third_gear => :second_gear, :second_gear => :first_gear
    end

    event :crash do
      transition all - [:parked, :stalled] => :stalled, :unless => :auto_shop_busy?
    end

    event :repair do
      # The first transition that matches the state and passes its conditions
      # will be used
      transition :stalled => :parked, :if => :auto_shop_busy?
      transition :stalled => same
    end

    state :parked do
      def speed
        0
      end
    end

    state :idling, :first_gear do
      def speed
        10
      end
    end

    state :second_gear do
      def speed
        20
      end
    end
  end

  state_machine :alarm_state, :initial => :active, :namespace => 'alarm' do
    event :enable do
      transition all => :active
    end

    event :disable do
      transition all => :off
    end

    state :active, :value => 1
    state :off, :value => 0
  end

  def initialize
    @seatbelt_on = false
    @time_used = 0
    super() # NOTE: This *must* be called, otherwise states won't get initialized
  end

  def put_on_seatbelt
    @seatbelt_on = true
  end

  def auto_shop_busy?
    false
  end

  def tow
    # tow the vehicle
  end

  def fix
    # get the vehicle fixed by a mechanic
  end

  def log_start_failure
    # log a failed attempt to start the vehicle
  end
end
```

**Note** the comment made on the *initialize* method in the class. In order for
state machine attributes to be properly initialized, `super()` must be called.
See `StateMachine::MacroMethods` for more information about this.

Using the above class as an example, you can interact with the state machine
like so:

```ruby
vehicle = Vehicle.new           # => #<Vehicle:0xb7cf4eac @state="parked", @seatbelt_on=false>
vehicle.state                   # => "parked"
vehicle.state_name              # => :parked
vehicle.human_state_name        # => "parked"
vehicle.parked?                 # => true
vehicle.can_ignite?             # => true
vehicle.ignite_transition       # => #<StateMachine::Transition attribute=:state event=:ignite from="parked" from_name=:parked to="idling" to_name=:idling>
vehicle.state_events            # => [:ignite]
vehicle.state_transitions       # => [#<StateMachine::Transition attribute=:state event=:ignite from="parked" from_name=:parked to="idling" to_name=:idling>]
vehicle.speed                   # => 0

vehicle.ignite                  # => true
vehicle.parked?                 # => false
vehicle.idling?                 # => true
vehicle.speed                   # => 10
vehicle                         # => #<Vehicle:0xb7cf4eac @state="idling", @seatbelt_on=true>

vehicle.shift_up                # => true
vehicle.speed                   # => 10
vehicle                         # => #<Vehicle:0xb7cf4eac @state="first_gear", @seatbelt_on=true>

vehicle.shift_up                # => true
vehicle.speed                   # => 20
vehicle                         # => #<Vehicle:0xb7cf4eac @state="second_gear", @seatbelt_on=true>

# The bang (!) operator can raise exceptions if the event fails
vehicle.park!                   # => StateMachine::InvalidTransition: Cannot transition state via :park from :second_gear

# Generic state predicates can raise exceptions if the value does not exist
vehicle.state?(:parked)         # => false
vehicle.state?(:invalid)        # => IndexError: :invalid is an invalid name

# Namespaced machines have uniquely-generated methods
vehicle.alarm_state             # => 1
vehicle.alarm_state_name        # => :active

vehicle.can_disable_alarm?      # => true
vehicle.disable_alarm           # => true
vehicle.alarm_state             # => 0
vehicle.alarm_state_name        # => :off
vehicle.can_enable_alarm?       # => true

vehicle.alarm_off?              # => true
vehicle.alarm_active?           # => false

# Events can be fired in parallel
vehicle.fire_events(:shift_down, :enable_alarm) # => true
vehicle.state_name                              # => :first_gear
vehicle.alarm_state_name                        # => :active

vehicle.fire_events!(:ignite, :enable_alarm)    # => StateMachine::InvalidTransition: Cannot run events in parallel: ignite, enable_alarm

# Human-friendly names can be accessed for states/events
Vehicle.human_state_name(:first_gear)               # => "first gear"
Vehicle.human_alarm_state_name(:active)             # => "active"

Vehicle.human_state_event_name(:shift_down)         # => "shift down"
Vehicle.human_alarm_state_event_name(:enable)       # => "enable"

# Available transition paths can be analyzed for an object
vehicle.state_paths                                       # => [[#<StateMachine::Transition ...], [#<StateMachine::Transition ...], ...]
vehicle.state_paths.to_states                             # => [:parked, :idling, :first_gear, :stalled, :second_gear, :third_gear]
vehicle.state_paths.events                                # => [:park, :ignite, :shift_up, :idle, :crash, :repair, :shift_down]

# Find all paths that start and end on certain states
vehicle.state_paths(:from => :parked, :to => :first_gear) # => [[
                                                          #       #<StateMachine::Transition attribute=:state event=:ignite from="parked" ...>,
                                                          #       #<StateMachine::Transition attribute=:state event=:shift_up from="idling" ...>
                                                          #    ]]
# Skipping state_machine and writing to attributes directly
vehicle.state = "parked"
vehicle.state                   # => "parked"
vehicle.state_name              # => :parked

# *Note* that the following is not supported (see StateMachine::MacroMethods#state_machine):
# vehicle.state = :parked
```

## Integrations ##

In addition to being able to define state machines on all Ruby classes, a set of
out-of-the-box integrations are available for some of the more popular Ruby
libraries. These integrations add library-specific behavior, allowing for state
machines to work more tightly with the conventions defined by those libraries.

The integrations currently available include:

* ActiveModel classes
* ActiveRecord models
* DataMapper resources
* Mongoid models
* MongoMapper models
* Sequel models

A brief overview of these integrations is described below.

### ActiveModel ###

The ActiveModel integration is useful for both standalone usage and for providing
the base implementation for ORMs which implement the ActiveModel API. This
integration adds support for validation errors, dirty attribute tracking, and
observers. For example,

```ruby
class Vehicle
  include ActiveModel::Dirty
  include ActiveModel::Validations
  include ActiveModel::Observing

  attr_accessor :state
  define_attribute_methods [:state]

  state_machine :initial => :parked do
    before_transition :parked => any - :parked, :do => :put_on_seatbelt
    after_transition any => :parked do |vehicle, transition|
      vehicle.seatbelt = 'off'
    end
    around_transition :benchmark

    event :ignite do
      transition :parked => :idling
    end

    state :first_gear, :second_gear do
      validates_presence_of :seatbelt_on
    end
  end

  def put_on_seatbelt
    ...
  end

  def benchmark
    ...
    yield
    ...
  end
end

class VehicleObserver < ActiveModel::Observer
  # Callback for :ignite event *before* the transition is performed
  def before_ignite(vehicle, transition)
    # log message
  end

  # Generic transition callback *after* the transition is performed
  def after_transition(vehicle, transition)
    Audit.log(vehicle, transition)
  end

  # Generic callback after the transition fails to perform
  def after_failure_to_transition(vehicle, transition)
    Audit.error(vehicle, transition)
  end
end
```

For more information about the various behaviors added for ActiveModel state
machines and how to build new integrations that use ActiveModel, see
`StateMachine::Integrations::ActiveModel`.

### ActiveRecord ###

The ActiveRecord integration adds support for database transactions, automatically
saving the record, named scopes, validation errors, and observers. For example,

```ruby
class Vehicle < ActiveRecord::Base
  state_machine :initial => :parked do
    before_transition :parked => any - :parked, :do => :put_on_seatbelt
    after_transition any => :parked do |vehicle, transition|
      vehicle.seatbelt = 'off'
    end
    around_transition :benchmark

    event :ignite do
      transition :parked => :idling
    end

    state :first_gear, :second_gear do
      validates_presence_of :seatbelt_on
    end
  end

  def put_on_seatbelt
    ...
  end

  def benchmark
    ...
    yield
    ...
  end
end

class VehicleObserver < ActiveRecord::Observer
  # Callback for :ignite event *before* the transition is performed
  def before_ignite(vehicle, transition)
    # log message
  end

  # Generic transition callback *after* the transition is performed
  def after_transition(vehicle, transition)
    Audit.log(vehicle, transition)
  end
end
```

For more information about the various behaviors added for ActiveRecord state
machines, see `StateMachine::Integrations::ActiveRecord`.

### DataMapper ###

Like the ActiveRecord integration, the DataMapper integration adds support for
database transactions, automatically saving the record, named scopes, Extlib-like
callbacks, validation errors, and observers. For example,

```ruby
class Vehicle
  include DataMapper::Resource

  property :id, Serial
  property :state, String

  state_machine :initial => :parked do
    before_transition :parked => any - :parked, :do => :put_on_seatbelt
    after_transition any => :parked do |transition|
      self.seatbelt = 'off' # self is the record
    end
    around_transition :benchmark

    event :ignite do
      transition :parked => :idling
    end

    state :first_gear, :second_gear do
      validates_presence_of :seatbelt_on
    end
  end

  def put_on_seatbelt
    ...
  end

  def benchmark
    ...
    yield
    ...
  end
end

class VehicleObserver
  include DataMapper::Observer

  observe Vehicle

  # Callback for :ignite event *before* the transition is performed
  before_transition :on => :ignite do |transition|
    # log message (self is the record)
  end

  # Generic transition callback *after* the transition is performed
  after_transition do |transition|
    Audit.log(self, transition) # self is the record
  end

  around_transition do |transition, block|
    # mark start time
    block.call
    # mark stop time
  end

  # Generic callback after the transition fails to perform
  after_transition_failure do |transition|
    Audit.log(self, transition) # self is the record
  end
end
```

**Note** that the DataMapper::Observer integration is optional and only available
when the dm-observer library is installed.

For more information about the various behaviors added for DataMapper state
machines, see `StateMachine::Integrations::DataMapper`.

### Mongoid ###

The Mongoid integration adds support for automatically saving the record,
basic scopes, validation errors, and observers. For example,

```ruby
class Vehicle
  include Mongoid::Document

  state_machine :initial => :parked do
    before_transition :parked => any - :parked, :do => :put_on_seatbelt
    after_transition any => :parked do |vehicle, transition|
      vehicle.seatbelt = 'off' # self is the record
    end
    around_transition :benchmark

    event :ignite do
      transition :parked => :idling
    end

    state :first_gear, :second_gear do
      validates_presence_of :seatbelt_on
    end
  end

  def put_on_seatbelt
    ...
  end

  def benchmark
    ...
    yield
    ...
  end
end

class VehicleObserver < Mongoid::Observer
  # Callback for :ignite event *before* the transition is performed
  def before_ignite(vehicle, transition)
    # log message
  end

  # Generic transition callback *after* the transition is performed
  def after_transition(vehicle, transition)
    Audit.log(vehicle, transition)
  end
end
```

For more information about the various behaviors added for Mongoid state
machines, see `StateMachine::Integrations::Mongoid`.

### MongoMapper ###

The MongoMapper integration adds support for automatically saving the record,
basic scopes, validation errors and callbacks. For example,

```ruby
class Vehicle
  include MongoMapper::Document

  state_machine :initial => :parked do
    before_transition :parked => any - :parked, :do => :put_on_seatbelt
    after_transition any => :parked do |vehicle, transition|
      vehicle.seatbelt = 'off' # self is the record
    end
    around_transition :benchmark

    event :ignite do
      transition :parked => :idling
    end

    state :first_gear, :second_gear do
      validates_presence_of :seatbelt_on
    end
  end

  def put_on_seatbelt
    ...
  end

  def benchmark
    ...
    yield
    ...
  end
end
```

For more information about the various behaviors added for MongoMapper state
machines, see `StateMachine::Integrations::MongoMapper`.

### Sequel ###

Like the ActiveRecord integration, the Sequel integration adds support for
database transactions, automatically saving the record, named scopes, validation
errors and callbacks. For example,

```ruby
class Vehicle < Sequel::Model
  state_machine :initial => :parked do
    before_transition :parked => any - :parked, :do => :put_on_seatbelt
    after_transition any => :parked do |transition|
      self.seatbelt = 'off' # self is the record
    end
    around_transition :benchmark

    event :ignite do
      transition :parked => :idling
    end

    state :first_gear, :second_gear do
      validates_presence_of :seatbelt_on
    end
  end

  def put_on_seatbelt
    ...
  end

  def benchmark
    ...
    yield
    ...
  end
end
```

For more information about the various behaviors added for Sequel state
machines, see `StateMachine::Integrations::Sequel`.

## Syntax flexibility ##

Although state_machine introduces a simplified syntax, it still remains
backwards compatible with previous versions and other state-related libraries by
providing some flexibility around how transitions are defined. See below for an
overview of these syntaxes.

### Verbose syntax ###

In general, it's recommended that state machines use the implicit syntax for
transitions. However, you can be a little more explicit and verbose about
transitions by using the `:from`, `:except_from`, `:to`,
and `:except_to` options.

For example, transitions and callbacks can be defined like so:

```ruby
class Vehicle
  state_machine :initial => :parked do
    before_transition :from => :parked, :except_to => :parked, :do => :put_on_seatbelt
    after_transition :to => :parked do |transition|
      self.seatbelt = 'off' # self is the record
    end

    event :ignite do
      transition :from => :parked, :to => :idling
    end
  end
end
```

### Transition context ###

Some flexibility is provided around the context in which transitions can be
defined. In almost all examples throughout the documentation, transitions are
defined within the context of an event. If you prefer to have state machines
defined in the context of a **state** either out of preference or in order to
easily migrate from a different library, you can do so as shown below:

```ruby
class Vehicle
  state_machine :initial => :parked do
    ...

    state :parked do
      transition :to => :idling, :on => [:ignite, :shift_up], :if => :seatbelt_on?

      def speed
        0
      end
    end

    state :first_gear do
      transition :to => :second_gear, :on => :shift_up

      def speed
        10
      end
    end

    state :idling, :first_gear do
      transition :to => :parked, :on => :park
    end
  end
end
```

In the above example, there's no need to specify the +from+ state for each
transition since it's inferred from the context.

You can also define transitions completely outside the context of a particular
state / event. This may be useful in cases where you're building a state
machine from a data store instead of part of the class definition. See the
example below:

```ruby
class Vehicle
  state_machine :initial => :parked do
    ...

    transition :parked => :idling, :on => [:ignite, :shift_up]
    transition :first_gear => :second_gear, :second_gear => :third_gear, :on => :shift_up
    transition [:idling, :first_gear] => :parked, :on => :park
    transition [:idling, :first_gear] => :parked, :on => :park
    transition all - [:parked, :stalled] => :stalled, :unless => :auto_shop_busy?
  end
end
```

Notice that in these alternative syntaxes:

* You can continue to configure `:if` and `:unless` conditions
* You can continue to define **from** states (when in the machine context) using
the **all**, **any**, and **same** helper methods

## Static / Dynamic definitions ##

In most cases, the definition of a state machine is **static**. That is to say,
the states, events and possible transitions are known ahead of time even though
they may depend on data that's only known at runtime. For example, certain
transitions may only be available depending on an attribute on that object it's
being run on. All of the documentation in this library define static machines
like so:

```ruby
class Vehicle
  state_machine :state, :initial => :parked do
    event :park do
      transition [:idling, :first_gear] => :parked
    end

    ...
  end
end
```

However, there may be cases where the definition of a state machine is **dynamic**.
This means that you don't know the possible states or events for a machine until
runtime. For example, you may allow users in your application to manage the
state machine of a project or task in your system. This means that the list of
transitions (and their associated states / events) could be stored externally,
such as in a database. In a case like this, you can define dynamically-generated
state machines like so:

```ruby
class Vehicle
  # Replace this with an external source (like a db)
  def transitions
    [
      {:parked => :idling, :on => :ignite},
      {:idling => :first_gear, :first_gear => :second_gear, :on => :shift_up},
      ...
    ]
  end

  # Create a state machine for this vehicle instance dynamically based on the
  # transitions defined from the source above
  def machine
    @machine ||= VehicleMachine.new(transitions)
  end
end

class VehicleMachine
  def self.new(transitions)
    machine = Class.new do
      # Provide easy access to the state machine definition
      def definition
        self.class.state_machine
      end
    end

    # Define the machine
    machine.state_machine(:initial => :parked) do
      transitions.each {|attrs| transition(attrs)}
    end
    machine.new
  end
end

vehicle = Vehicle.new                   # => #<Vehicle:0xb7236b50>
vehicle.machine                         # => #<#<Class:0xb723541c>:0xb722fa30 @state="parked">
vehicle.machine.state                   # => "parked"
vehicle.machine.ignite                  # => true
vehicle.machine.state                   # => "idling
vehicle.machine.state_transitions       # => [#<StateMachine::Transition ...>]
vehicle.machine.definition.states.keys  # => :first_gear, :second_gear, :parked, :idling
```

As you can see, state_machine provides enough flexibility for you to be able
to create new machine definitions on the fly based on an external source of
transitions.

## Tools ##

### Generating graphs ###

This library comes with built-in support for generating di-graphs based on the
events, states, and transitions defined for a state machine using [GraphViz](http://www.graphviz.org]).
This requires that both the `ruby-graphviz` gem and graphviz library be
installed on the system.

#### Examples ####

To generate a graph for a specific file / class:

```
rake state_machine:draw FILE=vehicle.rb CLASS=Vehicle
```

To save files to a specific path:

```
rake state_machine:draw FILE=vehicle.rb CLASS=Vehicle TARGET=files
```

To customize the image format / orientation:

```
rake state_machine:draw FILE=vehicle.rb CLASS=Vehicle FORMAT=jpg ORIENTATION=landscape
```

To generate multiple state machine graphs:

```
rake state_machine:draw FILE=vehicle.rb,car.rb CLASS=Vehicle,Car
```

**Note** that this will generate a different file for every state machine defined
in the class. The generated files will use an output filename of the format
\#{class_name}\_#{machine_name}.\#{format}.

For examples of actual images generated using this task, see those under the
examples folder.

### Interactive graphs ###

Jean Bovet's [Visual Automata Simulator](http://www.cs.usfca.edu/~jbovet/vas.html)
is a great tool for "simulating, visualizing and transforming finite state
automata and Turing Machines". It can help in the creation of states and events
for your models. It is cross-platform, written in Java.

## Web Frameworks ##

### Ruby on Rails ###

Integrating state\_machine into your Ruby on Rails application is straightforward
and provides a few additional features specific to the framework. To get
started, following the steps below.

#### 1. Install the gem ####

If using Rails 2.x:

```ruby
# In config/environment.rb
...
Rails::Initializer.run do |config|
  ...
  config.gem 'state_machine', :version => '~> 1.0'
  ...
end
```

If using Rails 3.x or up:

```ruby
# In Gemfile
...
gem 'state_machine'
gem 'ruby-graphviz', :require => 'graphviz' # Optional: only required for graphing
```

As usual, run `bundle install` to load the gems.

#### 2. Create a model ####

Create a model with a field to store the state, along with other any other
fields your application requires:

```
$ rails generate model Vehicle state:string
$ rake db:migrate
```

#### 3. Configure the state machine ####

Add the state machine to your model.  Following the examples above,
*app/models/vehicle.rb* might become:

```ruby
class Vehicle < ActiveRecord::Base
  state_machine :initial => :parked do
    before_transition :parked => any - :parked, :do => :put_on_seatbelt
    ...
  end
end
```

#### Rake tasks ####

There is a special integration Rake task for generating state machines for
classes used in a Ruby on Rails application. This task will load the application
environment, meaning that it's unnecessary to specify the actual file to load.

For example,

```
rake state_machine:draw CLASS=Vehicle
```

If you are using this library as a gem in Rails 2.x, the following must be added
to the end of your application's Rakefile in order for the above task to work:

```ruby
require 'tasks/state_machine'
```

### Merb ###

#### Rake tasks ####

Like Ruby on Rails, there is a special integration Rake task for generating
state machines for classes used in a Merb application. This task will load the
application environment, meaning that it's unnecessary to specify the actual
files to load.

For example,

```
rake state_machine:draw CLASS=Vehicle
```

## Testing ##

To run the core test suite (does **not** test any of the integrations):

```
bundle install
bundle exec rake test
```

To run integration tests:

```
bundle install
rake appraisal:install
rake appraisal:test
```

You can also test a specific version:

```
rake appraisal:active_model-3.0.0 test
rake appraisal:active_record-2.0.0 test
rake appraisal:data_mapper-0.9.4 test
rake appraisal:mongoid-2.0.0 test
rake appraisal:mongo_mapper-0.5.5 test
rake appraisal:sequel-2.8.0 test
```

## Caveats ##

The following caveats should be noted when using state_machine:

* DataMapper: Attribute-based event transitions are disabled when dm-validations 0.9.4 - 0.9.6 is in use
* Overridden event methods won't get invoked when using attribute-based event transitions
* around\_transition callbacks in ORM integrations won't work on JRuby since it doesn't support continuations

## Dependencies ##

* Ruby 1.8.6 or later

If using specific integrations:

* [ActiveModel](http://rubyonrails.org) integration: 3.0.0 or later
* [ActiveRecord](http://rubyonrails.org) integration: 2.0.0 or later
* [DataMapper](http://datamapper.org) integration: 0.9.4 or later
* [Mongoid](http://mongoid.org) integration: 2.0.0 or later
* [MongoMapper](http://mongomapper.com) integration: 0.5.5 or later
* [Sequel](http://sequel.rubyforge.org) integration: 2.8.0 or later

If graphing state machine:

* [ruby-graphviz](http://github.com/glejeune/Ruby-Graphviz): 0.9.0 or later
