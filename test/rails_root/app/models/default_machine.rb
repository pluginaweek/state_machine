class DefaultMachine < ActiveRecord::Base
  acts_as_state_machine :initial => :dummy
end