class CreateOutboxerMessages < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_messages do |t|
      t.string :status, null: false, limit: 255

      t.text :messageable_id, null: false
      t.text :messageable_type, null: false

      t.timestamps
    end

    add_index :outboxer_messages, :status
    add_index :outboxer_messages, [:status, :updated_at]
  end

  def down
    drop_table :outboxer_messages if table_exists?(:outboxer_messages)
  end
end
