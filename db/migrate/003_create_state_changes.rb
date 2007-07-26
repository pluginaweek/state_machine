class CreateStateChanges < ActiveRecord::Migration
  def self.up
    create_table :state_changes do |t|
      t.column :stateful_id,    :integer, :null => false, :references => nil
      t.column :stateful_type,  :string, :null => false
      t.column :from_state_id,  :integer, :references => :states
      t.column :to_state_id,    :integer, :null => false, :references => :states
      t.column :event_id,       :integer
      t.column :occurred_at,    :timestamp, :null => false
    end
  end
  
  def self.down
    drop_table :state_changes
  end
end