class CreateSwitches < ActiveRecord::Migration
  def self.up
    create_table :switches do |t|
      t.column :device, :string, :null => false, :default => 'light'
      # sqlite gets fed up with NOT NULL columns having default NULL when using add_column
      t.column :state_id, :integer, :null => false, :unsigned => true
    end
  end
  
  def self.down
    drop_table :switches
  end
end