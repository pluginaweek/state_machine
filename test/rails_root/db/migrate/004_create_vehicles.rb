class CreateVehicles < ActiveRecord::Migration
  def self.up
    create_table :vehicles do |t|
      t.column :highway_id,         :integer, :null => false, :default => 1, :unsigned => true
      t.column :auto_shop_id,       :integer, :null => false, :default => 1, :unsigned => true
      t.column :seatbelt_on,        :boolean, :null => false, :default => true
      t.column :insurance_premium,  :integer, :null => false, :default => 50
      t.column :type,               :string
      # sqlite gets fed up with NOT NULL columns having default NULL when using add_column
      t.column :state_id, :integer, :null => false, :unsigned => true
    end
  end
  
  def self.down
    drop_table :vehicles
  end
end