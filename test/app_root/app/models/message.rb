class Message < ActiveRecord::Base
  has_states :initial => :dummy
end