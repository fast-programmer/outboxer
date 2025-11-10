class CreateOutboxerMessageCounters < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_message_counters do |t|
      t.string  :hostname, limit: 255, null: false
      t.integer :process_id, null: false
      t.integer :thread_id, null: false

      t.integer :queued_count, null: false
      t.datetime :queued_count_last_updated_at, precision: 6

      t.integer :publishing_count, null: false
      t.datetime :publishing_count_last_updated_at, precision: 6

      t.integer :published_count, null: false
      t.datetime :published_count_last_updated_at, precision: 6

      t.integer :failed_count, null: false
      t.datetime :failed_count_last_updated_at, precision: 6

      t.timestamps null: false
    end

    add_index :outboxer_message_counters, [:hostname, :process_id, :thread_id],
      unique: true, name: "idx_outboxer_message_counters_identity"
  end

  def down
    drop_table :outboxer_message_counters if table_exists?(:outboxer_message_counters)
  end
end
