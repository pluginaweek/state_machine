class CreateStateDeadlines < ActiveRecord::Migration
  def self.up
    create_table :state_deadlines do |t|
      t.column :stateful_id,    :integer,   :null => false, :unsigned => true, :references => nil
      t.column :state_id,       :integer,   :null => false, :unsigned => true
      t.column :deadline,       :datetime,  :null => false
      t.column :type,           :string,    :null => false
    end
    add_index :state_deadlines, [:stateful_id, :state_id], :unique => true
  end
  
  def self.down
    drop_table :state_deadlines
  end
end