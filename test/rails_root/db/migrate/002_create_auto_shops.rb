class CreateAutoShops < ActiveRecord::Migration
  class AutoShop < ActiveRecord::Base
    acts_as_state_machine :initial => :dummy
  end
  
  def self.up
    create_table :auto_shops do |t|
      t.column :name, :string, :null => false
      t.column :num_customers, :integer, :null => false, :default => 0
    end
    
    AutoShop::State.migrate_up
  end
  
  def self.down
    AutoShop::State.migrate_down
    drop_table :auto_shops
  end
end