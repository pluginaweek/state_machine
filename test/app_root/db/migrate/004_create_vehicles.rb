class CreateVehicles < ActiveRecord::Migration
  def self.up
    create_table :vehicles do |t|
      t.column :highway_id, :integer, :null => false, :default => 1
      t.column :auto_shop_id, :integer, :null => false, :default => 1
      t.column :seatbelt_on, :boolean, :null => false, :default => true
      t.column :insurance_premium, :integer, :null => false, :default => 50
      t.column :type, :string
    end
    
    PluginAWeek::Has::States.migrate_up(:vehicles)
  end
  
  def self.down
    PluginAWeek::Has::States.migrate_down(:vehicles)
    
    drop_table :vehicles
  end
end