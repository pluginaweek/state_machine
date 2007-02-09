class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.column :sender, :string
      t.column :state_id, :integer, :null => false
    end
  end
  
  def self.down
    drop_table :messages
  end
end