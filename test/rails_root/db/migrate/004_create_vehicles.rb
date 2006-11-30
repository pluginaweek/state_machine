class CreateVehicles < ActiveRecord::Migration
  class Vehicle < ActiveRecord::Base
    acts_as_state_machine :initial => :dummy
  end
  
  def self.up
    create_table :vehicles do |t|
      t.column :highway_id,         :integer, :null => false, :unsigned => true
      t.column :seatbelt_on,        :boolean, :null => false, :default => true
      t.column :insurance_premium,  :integer, :null => false, :default => 50
      t.column :type,               :string,  :null => false
    end
    
    Vehicle::State.migrate_up
  end
  
  def self.down
    Vehicle::State.migrate_down
    drop_table :vehicles
  end
end