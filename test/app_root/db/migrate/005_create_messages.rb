class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.column :sender, :string
    end
    
    PluginAWeek::Has::States.migrate_up(:messages)
  end
  
  def self.down
    PluginAWeek::Has::States.migrate_down(:messages)
    
    drop_table :messages
  end
end