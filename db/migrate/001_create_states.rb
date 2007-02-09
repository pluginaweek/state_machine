class CreateStates < ActiveRecord::Migration
  def self.up
    create_table :states do |t|
      t.column :name,               :string, :null => false, :limit => 50
      t.column :short_description,  :string, :limit => 100
      t.column :long_description,   :string, :null => false, :limit => 1024
      t.column :owner_type,         :string, :null => false
    end
    add_index :states, [:name, :owner_type], :unique => true
  end
  
  def self.down
    drop_table :states
  end
end