class CreateAutoShops < ActiveRecord::Migration
  def self.up
    create_table :auto_shops do |t|
      t.column :name, :string, :null => false
      t.column :num_customers, :integer, :null => false, :default => 0
      t.column :state_id, :integer, :null => false
    end
  end
  
  def self.down
    drop_table :auto_shops
  end
end