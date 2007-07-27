class CreateTasks < ActiveRecord::Migration
  def self.up
    create_table :tasks do |t|
      t.column :name, :string
    end
    
    PluginAWeek::Has::States.migrate_up(:tasks)
  end
  
  def self.down
    PluginAWeek::Has::States.migrate_down(:tasks)
    
    drop_table :tasks
  end
end