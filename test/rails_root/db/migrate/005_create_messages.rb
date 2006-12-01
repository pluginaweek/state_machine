class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.column :sender, :string
      # sqlite gets fed up with NOT NULL columns having default NULL when using add_column
      t.column :state_id, :integer, :null => false, :unsigned => true
    end
  end
  
  def self.down
    drop_table :messages
  end
end