class CreateOutboxerMessages < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_messages do |t|
      t.string :status, limit: 255, null: false

      t.string :messageable_id, limit: 255, null: false
      t.string :messageable_type, limit: 255, null: false

      t.datetime :queued_at, precision: 6, null: false

      t.datetime :buffered_at, precision: 6

      t.datetime :updated_at, precision: 6, null: false
      t.string :updated_by_publisher_name, limit: 263 # 255 (hostname) + 1 (colon) + 7 (pid)
      t.bigint :updated_by_publisher_id
    end

    # messages by status count
    add_index :outboxer_messages, :status, name: 'idx_outboxer_status'

    # messages by status latency
    add_index :outboxer_messages, [:status, :updated_at],
      name: 'idx_outboxer_status_updated_at'

    # publisher latency
    add_index :outboxer_messages, [:updated_by_publisher_id, :updated_at],
      name: 'idx_outboxer_pub_id_updated_at'

    # publisher throughput
    add_index :outboxer_messages, [:status, :updated_by_publisher_id, :updated_at],
      name: 'idx_outboxer_status_pub_id_updated_at'
  end

  def down
    drop_table :outboxer_messages if table_exists?(:outboxer_messages)
  end
end
