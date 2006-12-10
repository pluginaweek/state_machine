class CreateEvents < ActiveRecord::Migration
  def self.up
    create_table :events do |t|
      t.column :name,               :string, :limit => 50,    :null => false
      t.column :short_description,  :string, :limit => 100
      t.column :long_description,   :string, :limit => 1024,  :null => false
      t.column :type,               :string
    end
    add_index :events, [:name, :type], :unique => true
  end
  
  def self.down
    drop_table :events
  end
end