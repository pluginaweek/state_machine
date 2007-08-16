class Highway < ActiveRecord::Base
  has_many  :vehicles,
              :extend => Vehicle::StateExtension
end