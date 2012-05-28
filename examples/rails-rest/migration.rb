class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name, :state, :access_state
    end
  end
end
