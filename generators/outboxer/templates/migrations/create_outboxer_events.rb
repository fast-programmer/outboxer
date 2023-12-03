class CreateOutboxerEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :outboxer_events do |t|
      t.text :status, null: false

      t.references :outboxer_eventable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :outboxer_events, %i[status created_at]
  end
end
