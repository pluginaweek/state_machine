class CreateAutoShops < ActiveRecord::Migration
  def self.up
    create_table :auto_shops do |t|
      t.column :name, :string, :null => false
      t.column :num_customers, :integer, :null => false, :default => 0
    end
    
    PluginAWeek::Has::States.migrate_up(:auto_shops)
  end
  
  def self.down
    PluginAWeek::Has::States.migrate_down(:switches)
    
    drop_table :auto_shops
  end
end