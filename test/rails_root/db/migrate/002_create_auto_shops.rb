class CreateAutoShops < ActiveRecord::Migration
  def self.up
    create_table :auto_shops do |t|
      t.column :name, :string, :null => false
      t.column :num_customers, :integer, :null => false, :default => 0
      # sqlite gets fed up with NOT NULL columns having default NULL when using add_column
      t.column :state_id, :integer, :null => false, :unsigned => true
    end
  end
  
  def self.down
    drop_table :auto_shops
  end
end