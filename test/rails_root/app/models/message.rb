class Message < ActiveRecord::Base
  acts_as_state_machine :initial => :dummy
end