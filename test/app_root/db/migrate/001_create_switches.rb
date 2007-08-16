class CreateSwitches < ActiveRecord::Migration
  def self.up
    create_table :switches do |t|
      t.column :device, :string, :null => false, :default => 'light'
    end
    
    PluginAWeek::Has::States.migrate_up(:switches)
  end
  
  def self.down
    PluginAWeek::Has::States.migrate_down(:switches)
    
    drop_table :switches
  end
end