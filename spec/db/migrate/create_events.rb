class CreateEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :events, force: true do |t|
      t.text :type, null: false
      t.jsonb :payload

      t.datetime :created_at, null: false

      t.references :eventable, polymorphic: true, null: false, index: true
    end

    add_index :events, [:eventable_type, :eventable_id, :created_at],
      name: 'index_events_on_eventable_and_created_at'
  end
end
