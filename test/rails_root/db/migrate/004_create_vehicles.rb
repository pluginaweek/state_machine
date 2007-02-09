class CreateVehicles < ActiveRecord::Migration
  def self.up
    create_table :vehicles do |t|
      t.column :highway_id,         :integer, :null => false, :default => 1
      t.column :auto_shop_id,       :integer, :null => false, :default => 1
      t.column :seatbelt_on,        :boolean, :null => false, :default => true
      t.column :insurance_premium,  :integer, :null => false, :default => 50
      t.column :type,               :string
      t.column :state_id, :integer, :null => false
    end
  end
  
  def self.down
    drop_table :vehicles
  end
end