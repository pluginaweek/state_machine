class CreateSwitches < ActiveRecord::Migration
  def self.up
    create_table :switches do |t|
      t.column :device, :string, :null => false, :default => 'light'
      t.column :state_id, :integer, :null => false
    end
  end
  
  def self.down
    drop_table :switches
  end
end