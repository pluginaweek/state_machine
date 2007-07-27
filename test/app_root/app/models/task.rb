class Task < ActiveRecord::Base
  has_states :initial => :dummy
end