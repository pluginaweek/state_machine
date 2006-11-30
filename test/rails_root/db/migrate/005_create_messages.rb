class CreateMessages < ActiveRecord::Migration
  class Message < ActiveRecord::Base
    acts_as_state_machine :initial => :dummy
  end
  
  def self.up
    create_table :messages do |t|
      t.column :sender, :string
    end
    
    Message::State.migrate_up
  end
  
  def self.down
    Message::State.migrate_down
    drop_table :messages
  end
end