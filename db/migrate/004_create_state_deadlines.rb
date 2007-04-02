class CreateStateDeadlines < ActiveRecord::Migration
  def self.up
    create_table :state_deadlines do |t|
      t.column :stateful_id,    :integer,   :null => false, :unsigned => true, :references => nil
      t.column :stateful_type,  :string,    :null => false
      t.column :state_id,       :integer,   :null => false, :unsigned => true
      t.column :deadline,       :datetime,  :null => false
    end
    add_index :state_deadlines, [:stateful_id, :stateful_type, :state_id], :unique => true, :name => 'index_state_deadlines_on_stateful_and_state_id'
  end
  
  def self.down
    drop_table :state_deadlines
  end
end