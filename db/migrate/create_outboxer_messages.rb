class CreateOutboxerMessages < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_messages do |t|
      t.string :status, limit: 255, null: false

      t.string :messageable_id, limit: 255, null: false
      t.string :messageable_type, limit: 255, null: false

      t.timestamps

      t.string :updated_by_hostname, limit: 255, null: false
      t.integer :updated_by_process_id, null: false
    end

    add_index :outboxer_messages, :status
    add_index :outboxer_messages, [:status, :updated_at]
  end

  def down
    drop_table :outboxer_messages if table_exists?(:outboxer_messages)
  end
end
