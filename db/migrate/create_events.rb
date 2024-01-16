class CreateEvents < ActiveRecord::Migration[6.1]
  def up
    create_table :events, force: true do |t|
      t.string :type, null: false
      t.jsonb :payload

      t.datetime :created_at, null: false

      t.references :eventable, polymorphic: true, null: false, index: true
    end
  end

  def down
    drop_table :events
  end
end
