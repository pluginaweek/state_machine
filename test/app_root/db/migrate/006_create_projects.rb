class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table :projects do |t|
      t.column :name, :string, :null => false
    end
    
    PluginAWeek::Has::States.migrate_up(:projects)
  end
  
  def self.down
    PluginAWeek::Has::States.migrate_down(:projects)
    
    drop_table :projects
  end
end