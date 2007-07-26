class CreateStates < ActiveRecord::Migration
  def self.up
    create_table :states do |t|
      t.column :name, :string, :null => false
      t.column :human_name, :string
      t.column :owner_type, :string, :null => false
    end
    add_index :states, [:name, :owner_type], :unique => true
  end
  
  def self.down
    drop_table :states
  end
end