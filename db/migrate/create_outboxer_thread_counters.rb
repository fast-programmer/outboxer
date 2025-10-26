class CreateOutboxerThreadCounters < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_thread_counters do |t|
      t.string  :hostname, limit: 255, null: false
      t.integer :process_id, null: false
      t.integer :thread_id, null: false

      t.integer :publisher_id

      t.integer :queued_count,     null: false
      t.integer :publishing_count, null: false
      t.integer :published_count,  null: false
      t.integer :failed_count,     null: false

      t.timestamps
    end

    add_index :outboxer_thread_counters, [:hostname, :process_id, :thread_id],
      unique: true, name: "idx_outboxer_thread_identity"

    add_index :outboxer_thread_counters,
      :updated_at, name: "idx_outboxer_thread_counters_updated_at"
  end

  def down
    drop_table :outboxer_thread_counters if table_exists?(:outboxer_thread_counters)
  end
end
