class CreateSwitches < ActiveRecord::Migration
  class Switch < ActiveRecord::Base
    acts_as_state_machine :initial => :dummy
  end
  
  def self.up
    create_table :switches do |t|
      t.column :device, :string, :default => 'light'
    end
    
    Switch::State.migrate_up
  end
  
  def self.down
    Switch::State.migrate_down
    drop_table :switches
  end
end